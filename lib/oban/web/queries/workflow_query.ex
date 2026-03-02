defmodule Oban.Web.WorkflowQuery do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @compile {:no_warn_undefined, Oban.Pro.Workflow}

  def all_workflows(params, conf) do
    limit = Map.get(params, :limit, 10)
    sort_by = Map.get(params, :sort_by, "inserted")
    sort_dir = Map.get(params, :sort_dir, "desc")

    workflow_ids = fetch_workflow_ids(conf, limit, sort_by, sort_dir)

    Enum.map(workflow_ids, &build_workflow(&1, conf))
  end

  defp fetch_workflow_ids(conf, limit, sort_by, sort_dir) do
    dir = String.to_existing_atom(sort_dir)

    query =
      Job
      |> where([j], fragment("? \\? 'workflow_id'", j.meta))
      |> where([j], fragment("NOT ? \\? 'sup_workflow_id'", j.meta))
      |> group_by([j], fragment("?->>'workflow_id'", j.meta))
      |> limit(^limit)
      |> select([j], %{workflow_id: fragment("?->>'workflow_id'", j.meta)})
      |> apply_sort(sort_by, dir)

    Repo.all(conf, query)
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
