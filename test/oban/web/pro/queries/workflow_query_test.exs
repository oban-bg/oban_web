if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.WorkflowQueryTest do
    use Oban.Web.ProCase

    alias Oban.Web.{Workflow, WorkflowQuery}
    alias Oban.Web.Workflows.Helpers

    setup context do
      name = start_supervised_oban!(Map.get(context, :oban_opts, []))

      {:ok, conf: Oban.config(name), oban: name}
    end

    describe "all_workflows/2 filtering" do
      test "filtering by workflow id", %{conf: conf} do
        insert_workflow!(workflow_id: "wf-alpha", steps: [[worker: "WorkerA"]])
        insert_workflow!(workflow_id: "wf-gamma", steps: [[worker: "WorkerB"]])

        assert ["wf-alpha"] == workflow_ids(conf, ids: ~w(wf-alpha))
        assert ["wf-gamma"] == workflow_ids(conf, ids: ~w(wf-gamma))
        assert [] == workflow_ids(conf, ids: ~w(wf-unknown))
      end

      test "filtering by workflow name", %{conf: conf} do
        insert_workflow!(workflow_id: "wf-1", workflow_name: "order-fulfillment")
        insert_workflow!(workflow_id: "wf-2", workflow_name: "data-migration")
        insert_workflow!(workflow_id: "wf-3")

        assert ["wf-1"] == workflow_ids(conf, names: ~w(order-fulfillment))
        assert ["wf-2"] == workflow_ids(conf, names: ~w(data-migration))
        assert [] == workflow_ids(conf, names: ~w(unknown-workflow))
      end

      test "filtering by queue", %{conf: conf} do
        insert_workflow!(workflow_id: "wf-media", steps: [[queue: "media"]])
        insert_workflow!(workflow_id: "wf-default", steps: [[queue: "default"]])

        assert ["wf-media"] == workflow_ids(conf, queues: ~w(media))
        assert ["wf-default"] == workflow_ids(conf, queues: ~w(default))
        assert ["wf-default", "wf-media"] == workflow_ids(conf, queues: ~w(media default))
        assert [] == workflow_ids(conf, queues: ~w(unknown))
      end

      test "filtering by worker", %{conf: conf} do
        insert_workflow!(workflow_id: "wf-video", steps: [[worker: "VideoProcessor"]])
        insert_workflow!(workflow_id: "wf-audio", steps: [[worker: "AudioProcessor"]])

        assert ["wf-video"] == workflow_ids(conf, workers: ~w(VideoProcessor))
        assert ["wf-audio"] == workflow_ids(conf, workers: ~w(AudioProcessor))
        assert [] == workflow_ids(conf, workers: ~w(UnknownWorker))
      end

      test "filtering by kind", %{conf: conf} do
        saga = run_failed_saga!()

        assert [saga.compensation_id] == workflow_ids(conf, kinds: ["compensation"])
        assert [saga.id] == workflow_ids(conf, kinds: ["standard"])

        assert Enum.sort([saga.id, saga.compensation_id]) ==
                 workflow_ids(conf, kinds: ["compensation", "standard"])
      end

      test "filtering by state", %{conf: conf} do
        insert_workflow!(workflow_id: "wf-exec")
        run_workflow!(workflow_id: "wf-done")

        assert ["wf-exec"] == workflow_ids(conf, states: ~w(executing))
        assert ["wf-done"] == workflow_ids(conf, states: ~w(completed))
      end
    end

    describe "custom prefix" do
      @tag oban_opts: [name: ObanPrivate, prefix: "private"]
      test "all_workflows aggregates with the configured prefix", %{conf: conf, oban: oban} do
        insert_workflow!(
          oban: oban,
          workflow_id: "parent-private",
          steps: [[worker: "ParentWorker"]],
          subs: [
            [workflow_id: "sub-priv-1", steps: [[worker: "ChildWorker1"]]],
            [workflow_id: "sub-priv-2", steps: [[worker: "ChildWorker2"]]]
          ]
        )

        [workflow] = WorkflowQuery.all_workflows(conf, %{})

        assert workflow.id == "parent-private"
        assert workflow.total == 3
      end

      @tag oban_opts: [name: ObanPrivate, prefix: "private"]
      test "get_workflow_graph resolves dependencies with the configured prefix", %{
        conf: conf,
        oban: oban
      } do
        insert_workflow!(
          oban: oban,
          workflow_id: "graph-parent",
          steps: [[name: :parent_step]],
          subs: [[workflow_id: "graph-sub", deps: [:parent_step]]]
        )

        %{sub_workflows: subs} = WorkflowQuery.get_workflow_graph(conf, "graph-parent")

        assert [sub] = subs
        assert sub.workflow_id == "graph-sub"
        assert sub.parent_dep == "parent_step"
      end
    end

    describe "get_workflow_graph/3 sub-workflow parent deps" do
      test "resolves parent_dep for every sub-workflow", %{conf: conf} do
        insert_workflow!(
          workflow_id: "parent",
          steps: [[name: :step_a], [name: :step_b]],
          subs: [
            [workflow_id: "sub-1", deps: [:step_a]],
            [workflow_id: "sub-2", deps: [:step_b]],
            [workflow_id: "sub-3"]
          ]
        )

        %{sub_workflows: subs} = WorkflowQuery.get_workflow_graph(conf, "parent")

        assert [{"sub-1", "step_a"}, {"sub-2", "step_b"}, {"sub-3", nil}] ==
                 subs |> Enum.map(&{&1.workflow_id, &1.parent_dep}) |> Enum.sort()
      end
    end

    describe "get_sub_workflows/3" do
      test "returns sub-workflows for a parent workflow", %{conf: conf} do
        insert_workflow!(
          workflow_id: "parent-wf",
          workflow_name: "parent",
          subs: [
            [workflow_id: "sub-wf-1", workflow_name: "child-1"],
            [workflow_id: "sub-wf-2", workflow_name: "child-2"]
          ]
        )

        subs = WorkflowQuery.get_sub_workflows(conf, "parent-wf")

        assert ["sub-wf-1", "sub-wf-2"] == subs |> Enum.map(& &1.id) |> Enum.sort()
      end

      test "respects the limit parameter", %{conf: conf} do
        insert_workflow!(
          workflow_id: "parent-wf",
          subs: [[workflow_id: "sub-1"], [workflow_id: "sub-2"], [workflow_id: "sub-3"]]
        )

        subs = WorkflowQuery.get_sub_workflows(conf, "parent-wf", 2)

        assert length(subs) == 2
      end

      test "returns empty list when no sub-workflows exist", %{conf: conf} do
        insert_workflow!(workflow_id: "lonely-wf")

        assert [] == WorkflowQuery.get_sub_workflows(conf, "lonely-wf")
      end
    end

    describe "get_workflow_graph/3 compensation metadata" do
      test "including the compensate declaration on forward jobs", %{conf: conf} do
        saga = run_failed_saga!()

        %{jobs: jobs} = WorkflowQuery.get_workflow_graph(conf, saga.id)

        charge = Enum.find(jobs, &(&1.meta["name"] == "charge"))
        ship = Enum.find(jobs, &(&1.meta["name"] == "ship"))

        assert %{"kind" => "worker"} = charge.meta["compensate"]
        refute ship.meta["compensate"]
      end

      test "including origin links on compensating jobs", %{conf: conf} do
        saga = run_failed_saga!()
        charge = saga.jobs["charge"]

        %{jobs: [job]} = WorkflowQuery.get_workflow_graph(conf, saga.compensation_id)

        assert job.meta["origin_job_id"] == charge.id
        assert job.meta["origin_name"] == "charge"
        assert job.meta["origin_workflow_id"] == saga.id
        assert job.meta["origin_worker"] =~ "ChargeCard"
      end
    end

    describe "suggest/3" do
      test "suggesting workflow kinds", %{conf: conf} do
        assert [{"compensation", _, _}] = WorkflowQuery.suggest("kinds:comp", conf)

        assert [{"compensation", _, _}, {"standard", _, _}] =
                 WorkflowQuery.suggest("kinds:", conf)
      end

      test "omitting compensation workflows from name and worker suggestions", %{conf: conf} do
        run_failed_saga!(workflow_name: "order-fulfillment")

        names = suggestions(WorkflowQuery.suggest("names:", conf))
        workers = suggestions(WorkflowQuery.suggest("workers:", conf))

        assert "order-fulfillment" in names

        refute Helpers.compensation_worker() in names
        refute Helpers.compensation_worker() in workers
      end
    end

    describe "get_compensation_steps/3" do
      test "pairing compensating jobs with the workers they roll back", %{conf: conf} do
        saga = run_failed_saga!()
        charge = saga.jobs["charge"]

        assert [step] = WorkflowQuery.get_compensation_steps(conf, saga.compensation_id)

        assert %{meta: %{"origin_name" => "charge"}} = step
        assert step.meta["origin_job_id"] == charge.id
        assert step.meta["origin_worker"] =~ "ChargeCard"
      end

      test "tolerating a compensating job whose origin was pruned", %{conf: conf} do
        saga = run_failed_saga!()

        Repo.delete!(saga.jobs["charge"])

        assert [step] = WorkflowQuery.get_compensation_steps(conf, saga.compensation_id)

        assert step.meta["origin_name"] == "charge"
        refute Map.has_key?(step.meta, "origin_worker")
      end
    end

    describe "compensation linking" do
      test "linking an origin and its compensation in both directions", %{conf: conf} do
        saga = run_failed_saga!(workflow_name: "order-fulfillment")

        %{id: origin_id, compensation_id: comp_id} = saga

        origin = WorkflowQuery.get_workflow(conf, origin_id)
        compensation = WorkflowQuery.get_workflow(conf, comp_id)

        assert %{id: ^comp_id} = WorkflowQuery.get_compensation(conf, origin)

        assert %{id: ^origin_id, name: "order-fulfillment"} =
                 WorkflowQuery.get_origin(conf, compensation)
      end

      test "returning nil for a workflow without compensation links", %{conf: conf} do
        insert_workflow!(workflow_id: "wf-plain")

        workflow = WorkflowQuery.get_workflow(conf, "wf-plain")

        assert nil == WorkflowQuery.get_compensation(conf, workflow)
        assert nil == WorkflowQuery.get_origin(conf, workflow)
      end
    end

    describe "get_root_workflow/3" do
      test "returning a root workflow unchanged", %{conf: conf} do
        insert_workflow!(workflow_id: "wf-root")

        workflow = WorkflowQuery.get_workflow(conf, "wf-root")

        assert %{id: "wf-root"} = WorkflowQuery.get_root_workflow(conf, workflow)
      end

      test "walking up nested sub-workflows to the family root", %{conf: conf} do
        insert_workflow!(
          workflow_id: "wf-root",
          workflow_name: "family",
          subs: [[workflow_id: "wf-mid", subs: [[workflow_id: "wf-leaf"]]]]
        )

        leaf = WorkflowQuery.get_workflow(conf, "wf-leaf")

        assert %{id: "wf-root", name: "family"} = WorkflowQuery.get_root_workflow(conf, leaf)
      end

      test "stopping at a workflow whose parent is missing", %{conf: conf} do
        insert_workflow!(workflow_id: "wf-gone", subs: [[workflow_id: "wf-orphan"]])

        # Pruning removed the parent, leaving the sub-workflow behind
        Repo.delete_all(where(Workflow, id: "wf-gone"))

        orphan = WorkflowQuery.get_workflow(conf, "wf-orphan")

        assert %{id: "wf-orphan"} = WorkflowQuery.get_root_workflow(conf, orphan)
      end

      test "stopping once the ancestor depth is exhausted", %{conf: conf} do
        insert_workflow!(workflow_id: "wf-root", subs: [[workflow_id: "wf-child"]])

        child = WorkflowQuery.get_workflow(conf, "wf-child")

        assert %{id: "wf-child"} = WorkflowQuery.get_root_workflow(conf, child, 0)
      end
    end

    defp suggestions(suggested), do: Enum.map(suggested, fn {value, _, _} -> value end)

    defp workflow_ids(conf, params) do
      conf
      |> WorkflowQuery.all_workflows(Map.new(params))
      |> Enum.map(& &1.id)
      |> Enum.sort()
    end
  end
end
