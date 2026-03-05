defmodule Oban.Web.WorkflowQuery do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}
  alias Oban.Pro.Workflow.Schema, as: Workflow
  alias Oban.Web.Search

  @compile {:no_warn_undefined, Oban.Pro.Workflow}
  @compile {:no_warn_undefined, Oban.Pro.Workflow.Schema}

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
      |> where([wf], not is_nil(wf.name))
      |> select([wf], wf.name)
      |> distinct(true)
      |> limit(100)

    conf
    |> Repo.all(query)
    |> Search.restrict_suggestions(fragment)
  end

  defp suggest_queues(fragment, conf) do
    query =
      Workflow
      |> where([wf], fragment("? \\? 'queues'", wf.meta))
      |> select([wf], fragment("jsonb_array_elements_text(?->'queues')", wf.meta))
      |> distinct(true)
      |> limit(100)

    conf
    |> Repo.all(query)
    |> Search.restrict_suggestions(fragment)
  end

  defp suggest_workers(fragment, conf) do
    query =
      Workflow
      |> where([wf], fragment("? \\? 'workers'", wf.meta))
      |> select([wf], fragment("jsonb_array_elements_text(?->'workers')", wf.meta))
      |> distinct(true)
      |> limit(100)

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

  def all_workflows(params, conf) do
    limit = Map.get(params, :limit, 10)
    sort_by = Map.get(params, :sort_by, "inserted")
    sort_dir = Map.get(params, :sort_dir, "desc")
    dir = String.to_existing_atom(sort_dir)

    Workflow
    |> where([wf], is_nil(wf.parent_id))
    |> apply_filters(params)
    |> apply_sort(sort_by, dir)
    |> limit(^limit)
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
    order_by(
      query,
      [wf],
      [
        {^dir,
         fragment("EXTRACT(EPOCH FROM (COALESCE(?, NOW()) - ?))", wf.completed_at, wf.started_at)}
      ]
    )
  end

  defp apply_sort(query, "total", dir) do
    order_by(
      query,
      [wf],
      [
        {^dir,
         fragment(
           "? + ? + ? + ? + ? + ? + ? + ?",
           wf.suspended,
           wf.available,
           wf.scheduled,
           wf.executing,
           wf.retryable,
           wf.completed,
           wf.cancelled,
           wf.discarded
         )}
      ]
    )
  end

  defp apply_sort(query, "progress", dir) do
    order_by(
      query,
      [wf],
      [
        {^dir,
         fragment(
           "?::float / NULLIF(? + ? + ? + ? + ? + ? + ? + ?, 0)",
           wf.completed,
           wf.suspended,
           wf.available,
           wf.scheduled,
           wf.executing,
           wf.retryable,
           wf.completed,
           wf.cancelled,
           wf.discarded
         )}
      ]
    )
  end

  defp apply_sort(query, _unknown, dir) do
    apply_sort(query, "inserted", dir)
  end

  defp build_workflow(%Workflow{} = wf) do
    pending = wf.available + wf.scheduled + wf.retryable
    finished = wf.completed + wf.cancelled + wf.discarded

    %{
      id: wf.id,
      name: wf.name,
      state: String.to_existing_atom(wf.state),
      total: wf.suspended + pending + wf.executing + finished,
      activity: %{
        suspended: wf.suspended,
        pending: pending,
        executing: wf.executing,
        finished: finished
      },
      started_at: wf.started_at,
      completed_at: wf.completed_at,
      queues: Map.get(wf.meta, "queues", []),
      display_name: wf.name || wf.id
    }
  end

  def get_workflow(conf, workflow_id) do
    query = where(Workflow, [wf], wf.id == ^workflow_id)
    Repo.one(conf, query)
  end

  def get_parent_workflow(conf, workflow_id) do
    query =
      Workflow
      |> where([wf], wf.id == ^workflow_id)
      |> where([wf], not is_nil(wf.parent_id))
      |> select([wf], wf.parent_id)

    case Repo.one(conf, query) do
      nil -> nil
      parent_id -> get_workflow(conf, parent_id)
    end
  end

  def get_sub_workflows(conf, workflow_id, limit \\ 10) do
    Workflow
    |> where([wf], wf.parent_id == ^workflow_id)
    |> limit(^limit)
    |> then(&Repo.all(conf, &1))
  end

  # TODO: Use meta ? 'workflow_id' condition to ensure index usage

  def get_workflow_graph(conf, workflow_id) do
    query =
      Job
      |> where([j], fragment("?->>'workflow_id' = ?", j.meta, ^workflow_id))
      |> select([j], %{
        id: j.id,
        state: j.state,
        worker: j.worker,
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
            j.meta,
            j.meta,
            j.meta,
            j.meta,
            j.meta,
            j.meta
          )
      })

    jobs = Repo.all(conf, query)

    # Get sub-workflow info (base query without parent_dep)
    base_sub_query =
      Job
      |> where([j], fragment("?->>'sup_workflow_id' = ?", j.meta, ^workflow_id))
      |> group_by([j], fragment("?->>'workflow_id'", j.meta))
      |> select([j], %{
        workflow_id: fragment("?->>'workflow_id'", j.meta),
        workflow_name: fragment("MAX(?->>'workflow_name')", j.meta),
        sub_name: fragment("MAX(?->>'sub_name')", j.meta),
        state:
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
            j.state,
            j.state,
            j.state,
            j.state,
            j.state
          )
      })

    # Wrap to add parent_dep via correlated subquery
    sub_query =
      from(s in subquery(base_sub_query),
        select: %{
          workflow_id: s.workflow_id,
          workflow_name: s.workflow_name,
          sub_name: s.sub_name,
          state: s.state,
          parent_dep:
            fragment(
              """
                (SELECT dep->>1
                 FROM oban_jobs j2,
                      LATERAL jsonb_array_elements(j2.meta->'deps') AS dep
                 WHERE j2.meta->>'workflow_id' = ?
                   AND jsonb_typeof(dep) = 'array'
                   AND dep->>0 = ?
                 LIMIT 1)
              """,
              s.workflow_id,
              ^workflow_id
            )
        }
      )

    sub_workflows = Repo.all(conf, sub_query)

    %{jobs: jobs, sub_workflows: sub_workflows}
  end
end
