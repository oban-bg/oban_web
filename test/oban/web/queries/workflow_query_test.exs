defmodule Oban.Web.Repo.WorkflowQueryTest do
  use Oban.Web.Case, async: false

  alias Oban.Web.{Workflow, WorkflowQuery}

  @moduletag :pro

  setup context do
    opts = Map.get(context, :oban_opts, [])
    name = start_supervised_oban!(opts)
    conf = Oban.config(name)

    {:ok, conf: conf}
  end

  describe "all_workflows/2 filtering" do
    test "filtering by workflow id", %{conf: conf} do
      insert_workflow!(conf, "wf-alpha", worker: "WorkerA")
      insert_workflow!(conf, "wf-gamma", worker: "WorkerB")

      assert ["wf-alpha"] == workflow_ids(conf, ids: ~w(wf-alpha))
      assert ["wf-gamma"] == workflow_ids(conf, ids: ~w(wf-gamma))
      assert [] == workflow_ids(conf, ids: ~w(wf-unknown))
    end

    test "filtering by workflow name", %{conf: conf} do
      insert_workflow!(conf, "wf-1", name: "order-fulfillment", worker: "WorkerA")
      insert_workflow!(conf, "wf-2", name: "data-migration", worker: "WorkerB")
      insert_workflow!(conf, "wf-3", worker: "WorkerC")

      assert ["wf-1"] == workflow_ids(conf, names: ~w(order-fulfillment))
      assert ["wf-2"] == workflow_ids(conf, names: ~w(data-migration))
      assert [] == workflow_ids(conf, names: ~w(unknown-workflow))
    end

    test "filtering by queue", %{conf: conf} do
      insert_workflow!(conf, "wf-media", worker: "MediaWorker", queue: "media")
      insert_workflow!(conf, "wf-default", worker: "DefaultWorker", queue: "default")

      assert ["wf-media"] == workflow_ids(conf, queues: ~w(media))
      assert ["wf-default"] == workflow_ids(conf, queues: ~w(default))

      assert sort(["wf-media", "wf-default"]) ==
               workflow_ids(conf, queues: ~w(media default)) |> sort()

      assert [] == workflow_ids(conf, queues: ~w(unknown))
    end

    test "filtering by worker", %{conf: conf} do
      insert_workflow!(conf, "wf-video", worker: "VideoProcessor")
      insert_workflow!(conf, "wf-audio", worker: "AudioProcessor")

      assert ["wf-video"] == workflow_ids(conf, workers: ~w(VideoProcessor))
      assert ["wf-audio"] == workflow_ids(conf, workers: ~w(AudioProcessor))
      assert [] == workflow_ids(conf, workers: ~w(UnknownWorker))
    end

    test "filtering by state", %{conf: conf} do
      insert_workflow!(conf, "wf-exec", worker: "WorkerA", state: "executing")
      insert_workflow!(conf, "wf-done", worker: "WorkerB", state: "completed")

      assert ["wf-exec"] == workflow_ids(conf, states: ~w(executing))
      assert ["wf-done"] == workflow_ids(conf, states: ~w(completed))
    end
  end

  describe "custom prefix" do
    @tag oban_opts: [name: ObanPrivate, prefix: "private"]
    test "all_workflows aggregates with the configured prefix", %{conf: conf} do
      insert_workflow!(conf, "parent-private", worker: "ParentWorker")
      insert_sub_workflow!(conf, "sub-priv-1", "parent-private", worker: "ChildWorker1")
      insert_sub_workflow!(conf, "sub-priv-2", "parent-private", worker: "ChildWorker2")

      [workflow] = WorkflowQuery.all_workflows(conf, %{})

      assert workflow.id == "parent-private"
      assert workflow.total == 3
    end

    @tag oban_opts: [name: ObanPrivate, prefix: "private"]
    test "get_workflow_graph resolves dependencies with the configured prefix", %{conf: conf} do
      insert_job!(%{},
        conf: conf,
        worker: "SubWorker",
        meta: %{
          workflow_id: "graph-sub",
          sup_workflow_id: "graph-parent",
          name: "sub-step",
          deps: [["graph-parent", "parent-step"]]
        }
      )

      %{sub_workflows: subs} = WorkflowQuery.get_workflow_graph(conf, "graph-parent")

      assert [sub] = subs
      assert sub.workflow_id == "graph-sub"
      assert sub.parent_dep == "parent-step"
    end
  end

  describe "get_sub_workflows/3" do
    test "returns sub-workflows for a parent workflow", %{conf: conf} do
      insert_workflow!(conf, "parent-wf", name: "parent", worker: "ParentWorker")
      insert_sub_workflow!(conf, "sub-wf-1", "parent-wf", name: "child-1", worker: "ChildWorker1")
      insert_sub_workflow!(conf, "sub-wf-2", "parent-wf", name: "child-2", worker: "ChildWorker2")

      subs = WorkflowQuery.get_sub_workflows(conf, "parent-wf")

      assert length(subs) == 2
      assert Enum.sort(Enum.map(subs, & &1.id)) == ["sub-wf-1", "sub-wf-2"]
    end

    test "respects the limit parameter", %{conf: conf} do
      insert_workflow!(conf, "parent-wf", worker: "ParentWorker")
      insert_sub_workflow!(conf, "sub-1", "parent-wf", worker: "Worker1")
      insert_sub_workflow!(conf, "sub-2", "parent-wf", worker: "Worker2")
      insert_sub_workflow!(conf, "sub-3", "parent-wf", worker: "Worker3")

      subs = WorkflowQuery.get_sub_workflows(conf, "parent-wf", 2)

      assert length(subs) == 2
    end

    test "returns empty list when no sub-workflows exist", %{conf: conf} do
      insert_workflow!(conf, "lonely-wf", worker: "LonelyWorker")

      assert [] == WorkflowQuery.get_sub_workflows(conf, "lonely-wf")
    end
  end

  defp workflow_ids(conf, params) do
    conf
    |> WorkflowQuery.all_workflows(Map.new(params))
    |> Enum.map(& &1.id)
    |> sort()
  end

  defp sort(list), do: Enum.sort(list)

  defp insert_workflow!(conf, workflow_id, opts) do
    state = Keyword.get(opts, :state, "available")
    queue = Keyword.get(opts, :queue, "default") |> to_string()
    worker = Keyword.get(opts, :worker, "DefaultWorker")

    workflow_attrs =
      %{
        id: workflow_id,
        name: Keyword.get(opts, :name),
        parent_id: nil,
        inserted_at: DateTime.utc_now(),
        meta: %{"queues" => [queue], "workers" => [worker]}
      }
      |> put_state_count(state)

    %Workflow{}
    |> Ecto.Changeset.cast(workflow_attrs, [
      :id,
      :name,
      :parent_id,
      :inserted_at,
      :meta,
      :suspended,
      :available,
      :scheduled,
      :executing,
      :retryable,
      :completed,
      :cancelled,
      :discarded
    ])
    |> conf.repo.insert!(prefix: conf.prefix)

    meta =
      %{workflow_id: workflow_id}
      |> maybe_put(:workflow_name, Keyword.get(opts, :name))

    job_opts =
      opts
      |> Keyword.take([:queue, :state])
      |> Keyword.put(:meta, meta)
      |> Keyword.put(:conf, conf)
      |> Keyword.put_new(:queue, :default)

    insert_job!(%{}, Keyword.put(job_opts, :worker, worker))
  end

  defp put_state_count(attrs, state) do
    base = %{
      suspended: 0,
      available: 0,
      scheduled: 0,
      executing: 0,
      retryable: 0,
      completed: 0,
      cancelled: 0,
      discarded: 0
    }

    state_key = String.to_existing_atom(state)
    counts = Map.put(base, state_key, 1)
    Map.merge(attrs, counts)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp insert_sub_workflow!(conf, workflow_id, parent_workflow_id, opts) do
    state = Keyword.get(opts, :state, "available")

    workflow_attrs =
      %{
        id: workflow_id,
        name: Keyword.get(opts, :name),
        parent_id: parent_workflow_id,
        inserted_at: DateTime.utc_now()
      }
      |> put_state_count(state)

    %Workflow{}
    |> Ecto.Changeset.cast(workflow_attrs, [
      :id,
      :name,
      :parent_id,
      :inserted_at,
      :suspended,
      :available,
      :scheduled,
      :executing,
      :retryable,
      :completed,
      :cancelled,
      :discarded
    ])
    |> conf.repo.insert!(prefix: conf.prefix)

    meta =
      maybe_put(
        %{workflow_id: workflow_id, sup_workflow_id: parent_workflow_id},
        :workflow_name,
        Keyword.get(opts, :name)
      )

    job_opts =
      opts
      |> Keyword.take([:queue, :state])
      |> Keyword.put(:meta, meta)
      |> Keyword.put(:conf, conf)
      |> Keyword.put_new(:queue, :default)

    worker = Keyword.get(opts, :worker, "DefaultWorker")

    insert_job!(%{}, Keyword.put(job_opts, :worker, worker))
  end
end
