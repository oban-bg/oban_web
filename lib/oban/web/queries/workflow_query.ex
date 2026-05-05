defmodule Oban.Web.WorkflowQuery do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}
  alias Oban.Web.{Search, Workflow}

  @default_sup_graph_limit 500
  @default_sub_graph_limit 100
  @default_suggest_limit 100

  defmacrop has_workflow_id(meta, workflow_id) do
    quote do
      fragment(
        "? \\? 'workflow_id' AND ?->>'workflow_id' = ?",
        unquote(meta),
        unquote(meta),
        unquote(workflow_id)
      )
    end
  end

  defmacrop has_sup_workflow_id(meta, workflow_id) do
    quote do
      fragment(
        "? \\? 'sup_workflow_id' AND ?->>'sup_workflow_id' = ?",
        unquote(meta),
        unquote(meta),
        unquote(workflow_id)
      )
    end
  end

  defmacrop duration_seconds(completed_at, started_at) do
    quote do
      fragment(
        "EXTRACT(EPOCH FROM (COALESCE(?, NOW()) - ?))",
        unquote(completed_at),
        unquote(started_at)
      )
    end
  end

  defmacrop total_jobs(wf) do
    quote do
      fragment(
        "? + ? + ? + ? + ? + ? + ? + ?",
        unquote(wf).suspended,
        unquote(wf).available,
        unquote(wf).scheduled,
        unquote(wf).executing,
        unquote(wf).retryable,
        unquote(wf).completed,
        unquote(wf).cancelled,
        unquote(wf).discarded
      )
    end
  end

  defmacrop progress_percent(wf) do
    quote do
      fragment(
        "?::float / NULLIF(? + ? + ? + ? + ? + ? + ? + ?, 0)",
        unquote(wf).completed,
        unquote(wf).suspended,
        unquote(wf).available,
        unquote(wf).scheduled,
        unquote(wf).executing,
        unquote(wf).retryable,
        unquote(wf).completed,
        unquote(wf).cancelled,
        unquote(wf).discarded
      )
    end
  end

  defmacrop job_graph_select(job) do
    quote do
      %{
        id: unquote(job).id,
        state: unquote(job).state,
        worker: unquote(job).worker,
        meta:
          fragment(
            """
            jsonb_build_object(
              'name', ?->>'name',
              'deps', ?->'deps',
              'workflow_name', ?->>'workflow_name',
              'decorated_name', ?->>'decorated_name',
              'handler', ?->>'handler',
              'context', (?->>'context')::boolean
            )
            """,
            unquote(job).meta,
            unquote(job).meta,
            unquote(job).meta,
            unquote(job).meta,
            unquote(job).meta,
            unquote(job).meta
          )
      }
    end
  end

  defmacrop aggregate_workflow_state(state) do
    quote do
      fragment(
        """
        CASE
          WHEN bool_or(? = 'executing') THEN 'executing'
          WHEN bool_or(? = 'discarded') THEN 'discarded'
          WHEN bool_or(? = 'cancelled') THEN 'cancelled'
          WHEN bool_or(? = 'retryable') THEN 'retryable'
          WHEN bool_and(? = 'completed') THEN 'completed'
          ELSE 'pending'
        END
        """,
        unquote(state),
        unquote(state),
        unquote(state),
        unquote(state),
        unquote(state)
      )
    end
  end

  defmacrop sub_workflow_parent_dep(prefix, sub_workflow_id, sup_workflow_id) do
    quote do
      fragment(
        """
        (SELECT dep->>1
         FROM ?.oban_jobs j2,
              LATERAL jsonb_array_elements(j2.meta->'deps') AS dep
         WHERE j2.meta->>'workflow_id' = ?
           AND jsonb_typeof(dep) = 'array'
           AND dep->>0 = ?
         LIMIT 1)
        """,
        identifier(^unquote(prefix)),
        unquote(sub_workflow_id),
        unquote(sup_workflow_id)
      )
    end
  end

  defmacrop sub_workflow_states(prefix, parent_id) do
    quote do
      fragment(
        """
        (SELECT COALESCE(array_agg(state), '{}') FROM ?.oban_workflows WHERE parent_id = ?)
        """,
        identifier(^unquote(prefix)),
        unquote(parent_id)
      )
    end
  end

  @suggest_qualifier [
    {"ids:", "workflow id", "ids:01234567-89ab-cdef"},
    {"names:", "workflow name", "names:order-fulfillment"},
    {"queues:", "queue name", "queues:default"},
    {"workers:", "worker module", "workers:MyApp.Worker"},
    {"states:", "workflow state", "states:executing"}
  ]

  @suggest_state [
    {"executing", "workflow is running", "states:executing"},
    {"completed", "workflow finished successfully", "states:completed"},
    {"cancelled", "workflow was cancelled", "states:cancelled"},
    {"discarded", "workflow has discarded jobs", "states:discarded"}
  ]

  @known_qualifiers MapSet.new(@suggest_qualifier, fn {qualifier, _, _} -> qualifier end)

  # Searching

  def filterable, do: ~w(ids names queues workers states)a

  def parse(terms) when is_binary(terms) do
    Search.parse(terms, &parse_term/1)
  end

  def suggest(terms, conf, _opts \\ []) do
    terms
    |> String.split(~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/)
    |> List.last()
    |> to_string()
    |> case do
      "" ->
        @suggest_qualifier

      last ->
        case String.split(last, ":", parts: 2) do
          ["ids", _frag] -> []
          ["names", frag] -> suggest_names(frag, conf)
          ["queues", frag] -> suggest_queues(frag, conf)
          ["workers", frag] -> suggest_workers(frag, conf)
          ["states", frag] -> suggest_static(frag, @suggest_state)
          [frag] -> suggest_static(frag, @suggest_qualifier)
          _ -> []
        end
    end
  end

  defp suggest_static(fragment, possibilities) do
    for {field, _, _} = suggest <- possibilities,
        String.starts_with?(field, fragment),
        do: suggest
  end

  defp suggest_names(fragment, conf) do
    query =
      Workflow
      |> select([wf], wf.name)
      |> distinct(true)
      |> limit(@default_suggest_limit)

    conf
    |> Repo.all(query)
    |> Search.restrict_suggestions(fragment)
  end

  defp suggest_queues(fragment, conf) do
    query =
      Workflow
      |> select([wf], fragment("jsonb_array_elements_text(?->'queues')", wf.meta))
      |> distinct(true)
      |> limit(@default_suggest_limit)

    conf
    |> Repo.all(query)
    |> Search.restrict_suggestions(fragment)
  end

  defp suggest_workers(fragment, conf) do
    query =
      Workflow
      |> select([wf], fragment("jsonb_array_elements_text(?->'workers')", wf.meta))
      |> distinct(true)
      |> limit(@default_suggest_limit)

    conf
    |> Repo.all(query)
    |> Search.restrict_suggestions(fragment)
  end

  def append(terms, choice) do
    Search.append(terms, choice, @known_qualifiers)
  end

  def complete(terms, conf) do
    case suggest(terms, conf) do
      [] -> terms
      [{match, _, _} | _] -> append(terms, match)
    end
  end

  defp parse_term("ids:" <> ids) do
    {:ids, String.split(ids, ",")}
  end

  defp parse_term("names:" <> names) do
    {:names, String.split(names, ",")}
  end

  defp parse_term("queues:" <> queues) do
    {:queues, String.split(queues, ",")}
  end

  defp parse_term("workers:" <> workers) do
    {:workers, String.split(workers, ",")}
  end

  defp parse_term("states:" <> states) do
    {:states, String.split(states, ",")}
  end

  defp parse_term(_term), do: {:none, ""}

  # Querying

  def all_workflows(conf, params) do
    limit = Map.get(params, :limit, 10)
    sort_by = Map.get(params, :sort_by, "inserted")
    sort_dir = Map.get(params, :sort_dir, "desc")
    dir = String.to_existing_atom(sort_dir)
    prefix = conf.prefix

    Workflow
    |> where([wf], is_nil(wf.parent_id))
    |> apply_filters(params)
    |> apply_sort(sort_by, dir)
    |> limit(^limit)
    |> select([wf], {wf, sub_workflow_states(prefix, wf.id)})
    |> then(&Repo.all(conf, &1))
    |> Enum.map(&build_workflow/1)
  end

  defp apply_filters(query, params) do
    query
    |> filter_by_ids(Map.get(params, :ids))
    |> filter_by_names(Map.get(params, :names))
    |> filter_by_states(Map.get(params, :states))
    |> filter_by_queues(Map.get(params, :queues))
    |> filter_by_workers(Map.get(params, :workers))
  end

  defp filter_by_ids(query, nil), do: query
  defp filter_by_ids(query, ids), do: where(query, [wf], wf.id in ^ids)

  defp filter_by_names(query, nil), do: query
  defp filter_by_names(query, names), do: where(query, [wf], wf.name in ^names)

  defp filter_by_states(query, nil), do: query
  defp filter_by_states(query, states), do: where(query, [wf], wf.state in ^states)

  defp filter_by_queues(query, nil), do: query

  defp filter_by_queues(query, queues) do
    where(query, [wf], fragment("?->'queues' \\?| ?", wf.meta, ^queues))
  end

  defp filter_by_workers(query, nil), do: query

  defp filter_by_workers(query, workers) do
    where(query, [wf], fragment("?->'workers' \\?| ?", wf.meta, ^workers))
  end

  defp apply_sort(query, "inserted", dir) do
    order_by(query, [wf], [{^dir, wf.inserted_at}])
  end

  defp apply_sort(query, "started", dir) do
    order_by(query, [wf], [{^dir, wf.started_at}])
  end

  defp apply_sort(query, "duration", dir) do
    order_by(query, [wf], [{^dir, duration_seconds(wf.completed_at, wf.started_at)}])
  end

  defp apply_sort(query, "total", dir) do
    order_by(query, [wf], [{^dir, total_jobs(wf)}])
  end

  defp apply_sort(query, "progress", dir) do
    order_by(query, [wf], [{^dir, progress_percent(wf)}])
  end

  defp apply_sort(query, _unknown, dir) do
    apply_sort(query, "inserted", dir)
  end

  defp build_workflow({%Workflow{} = wf, sub_states}) do
    pending = wf.available + wf.scheduled + wf.retryable
    finished = wf.completed + wf.cancelled + wf.discarded
    sub_activity = count_sub_activity(sub_states)

    %{
      id: wf.id,
      name: wf.name,
      state: String.to_existing_atom(wf.state),
      total: wf.suspended + pending + wf.executing + finished + length(sub_states),
      activity: %{
        suspended: wf.suspended + sub_activity.suspended,
        pending: pending + sub_activity.pending,
        executing: wf.executing + sub_activity.executing,
        finished: finished + sub_activity.finished
      },
      started_at: wf.started_at,
      completed_at: wf.completed_at,
      queues: Map.get(wf.meta, "queues", []),
      display_name: wf.name || wf.id
    }
  end

  defp count_sub_activity(states) do
    Enum.reduce(states, %{suspended: 0, pending: 0, executing: 0, finished: 0}, fn state, acc ->
      case state do
        "suspended" ->
          %{acc | suspended: acc.suspended + 1}

        "executing" ->
          %{acc | executing: acc.executing + 1}

        state when state in ~w(completed cancelled discarded) ->
          %{acc | finished: acc.finished + 1}

        _ ->
          %{acc | pending: acc.pending + 1}
      end
    end)
  end

  def get_workflow(conf, workflow_id) do
    query = where(Workflow, [wf], wf.id == ^workflow_id)

    Repo.one(conf, query)
  end

  def get_sup_workflow(conf, workflow_id) do
    Workflow
    |> join(:inner, [child], parent in Workflow, on: child.parent_id == parent.id)
    |> where([child, _parent], child.id == ^workflow_id)
    |> select([_child, parent], parent)
    |> then(&Repo.one(conf, &1))
  end

  def get_sub_workflows(conf, workflow_id, limit \\ 10) do
    Workflow
    |> where([wf], wf.parent_id == ^workflow_id)
    |> limit(^limit)
    |> then(&Repo.all(conf, &1))
  end

  def get_sub_workflow_jobs(conf, sub_workflow_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_sub_graph_limit)

    query =
      Job
      |> where([j], has_workflow_id(j.meta, ^sub_workflow_id))
      |> order_by([j], asc: j.id)
      |> limit(^limit)
      |> select([j], job_graph_select(j))

    jobs = Repo.all(conf, query)

    %{jobs: jobs, truncated: length(jobs) >= limit}
  end

  def get_workflow_graph(conf, workflow_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_sup_graph_limit)
    jobs = workflow_graph_jobs(conf, workflow_id, limit)
    subs = workflow_graph_subs(conf, workflow_id)

    %{jobs: jobs, sub_workflows: subs, truncated: length(jobs) >= limit}
  end

  defp workflow_graph_jobs(conf, workflow_id, limit) do
    query =
      Job
      |> where([j], has_workflow_id(j.meta, ^workflow_id))
      |> select([j], job_graph_select(j))
      |> order_by([j], asc: j.id)
      |> limit(^limit)

    Repo.all(conf, query)
  end

  defp workflow_graph_subs(conf, workflow_id) do
    prefix = conf.prefix

    base_query =
      Job
      |> where([j], has_sup_workflow_id(j.meta, ^workflow_id))
      |> group_by([j], fragment("?->>'workflow_id'", j.meta))
      |> select([j], %{
        workflow_id: fragment("?->>'workflow_id'", j.meta),
        workflow_name: fragment("MAX(?->>'workflow_name')", j.meta),
        sub_name: fragment("MAX(?->>'sub_name')", j.meta),
        state: aggregate_workflow_state(j.state)
      })

    query =
      from(s in subquery(base_query),
        select: %{
          workflow_id: s.workflow_id,
          workflow_name: s.workflow_name,
          sub_name: s.sub_name,
          state: s.state,
          parent_dep: sub_workflow_parent_dep(prefix, s.workflow_id, ^workflow_id)
        }
      )

    Repo.all(conf, query)
  end
end
