defmodule Oban.Web.WorkflowQuery do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Job, Repo}

  @compile {:no_warn_undefined, Oban.Pro.Workflow}

  def all_workflows(params, conf) do
    limit = Map.get(params, :limit, 20)

    workflow_ids = fetch_workflow_ids(conf, limit)

    Enum.map(workflow_ids, &build_workflow(&1, conf))
  end

  defp fetch_workflow_ids(conf, limit) do
    query =
      Job
      |> where([j], fragment("? \\? 'workflow_id'", j.meta))
      |> where([j], fragment("NOT ? \\? 'sup_workflow_id'", j.meta))
      |> group_by([j], fragment("?->>'workflow_id'", j.meta))
      |> order_by([j], desc: max(j.id))
      |> limit(^limit)
      |> select([j], %{workflow_id: fragment("?->>'workflow_id'", j.meta)})

    Repo.all(conf, query)
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
