defmodule Oban.Web.WorkflowQuery do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}
  alias Oban.Web.Search

  @compile {:no_warn_undefined, Oban.Pro.Workflow}

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
      Job
      |> where([j], fragment("? \\? 'workflow_name'", j.meta))
      |> select([j], fragment("DISTINCT ?->>'workflow_name'", j.meta))
      |> limit(100)

    conf
    |> Repo.all(query)
    |> Search.restrict_suggestions(fragment)
  end

  defp suggest_queues(fragment, conf) do
    query =
      Job
      |> where([j], fragment("? \\? 'workflow_id'", j.meta))
      |> select([j], j.queue)
      |> distinct(true)
      |> limit(100)

    conf
    |> Repo.all(query)
    |> Search.restrict_suggestions(fragment)
  end

  defp suggest_workers(fragment, conf) do
    query =
      Job
      |> where([j], fragment("? \\? 'workflow_id'", j.meta))
      |> select([j], j.worker)
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
    states = Map.get(params, :states)

    # Fetch extra workflows when filtering by state since that filter is applied in-memory
    fetch_limit = if states, do: limit * 3, else: limit

    params
    |> fetch_workflow_ids(conf, fetch_limit, sort_by, sort_dir)
    |> Enum.map(&build_workflow(&1, conf))
    |> filter_by_states(states)
    |> Enum.take(limit)
  end

  defp filter_by_states(workflows, nil), do: workflows

  defp filter_by_states(workflows, states) do
    Enum.filter(workflows, fn workflow ->
      to_string(workflow.state) in states
    end)
  end

  defp fetch_workflow_ids(params, conf, limit, sort_by, sort_dir) do
    dir = String.to_existing_atom(sort_dir)

    query =
      Job
      |> where([j], fragment("? \\? 'workflow_id'", j.meta))
      |> where([j], fragment("NOT ? \\? 'sup_workflow_id'", j.meta))
      |> apply_filters(params)
      |> group_by([j], fragment("?->>'workflow_id'", j.meta))
      |> limit(^limit)
      |> select([j], %{workflow_id: fragment("?->>'workflow_id'", j.meta)})
      |> apply_sort(sort_by, dir)

    Repo.all(conf, query)
  end

  defp apply_filters(query, params) do
    query
    |> filter_by_ids(Map.get(params, :ids))
    |> filter_by_names(Map.get(params, :names))
    |> filter_by_queues(Map.get(params, :queues))
    |> filter_by_workers(Map.get(params, :workers))
  end

  defp filter_by_ids(query, nil), do: query

  defp filter_by_ids(query, ids) do
    where(query, [j], fragment("?->>'workflow_id' = ANY(?)", j.meta, ^ids))
  end

  defp filter_by_names(query, nil), do: query

  defp filter_by_names(query, names) do
    where(query, [j], fragment("?->>'workflow_name' = ANY(?)", j.meta, ^names))
  end

  defp filter_by_queues(query, nil), do: query

  defp filter_by_queues(query, queues) do
    where(query, [j], j.queue in ^queues)
  end

  defp filter_by_workers(query, nil), do: query

  defp filter_by_workers(query, workers) do
    where(query, [j], j.worker in ^workers)
  end

  defp apply_sort(query, "inserted", dir) do
    order_by(query, [j], {^dir, max(j.id)})
  end

  defp apply_sort(query, "started", dir) do
    order_by(query, [j], {^dir, min(j.attempted_at)})
  end

  defp apply_sort(query, "duration", dir) do
    order_by(
      query,
      [j],
      {^dir,
       fragment(
         "EXTRACT(EPOCH FROM (MAX(COALESCE(?, NOW())) - MIN(?)))",
         j.completed_at,
         j.attempted_at
       )}
    )
  end

  defp apply_sort(query, "total", dir) do
    order_by(query, [j], {^dir, count(j.id)})
  end

  defp apply_sort(query, "progress", dir) do
    order_by(
      query,
      [j],
      {^dir,
       fragment(
         "COUNT(*) FILTER (WHERE ? = 'completed')::float / NULLIF(COUNT(*), 0)",
         j.state
       )}
    )
  end

  defp apply_sort(query, _unknown, dir) do
    apply_sort(query, "inserted", dir)
  end

  defp build_workflow(%{workflow_id: workflow_id}, conf) do
    status = Oban.Pro.Workflow.status(conf.name, workflow_id)

    queues = fetch_workflow_queues(conf, workflow_id)
    display_name = status.name || fetch_initial_worker(conf, workflow_id)

    Map.merge(status, %{
      queues: queues,
      display_name: display_name
    })
  end

  defp fetch_workflow_queues(conf, workflow_id) do
    query =
      Job
      |> where([j], fragment("?->>'workflow_id' = ?", j.meta, ^workflow_id))
      |> distinct([j], j.queue)
      |> select([j], j.queue)

    Repo.all(conf, query)
  end

  defp fetch_initial_worker(conf, workflow_id) do
    query =
      Job
      |> where([j], fragment("?->>'workflow_id' = ?", j.meta, ^workflow_id))
      |> order_by([j], asc: j.id)
      |> limit(1)
      |> select([j], j.worker)

    Repo.one(conf, query) || "Unknown"
  end
end
