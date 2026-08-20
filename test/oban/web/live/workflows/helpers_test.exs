defmodule Oban.Web.Workflows.HelpersTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Workflow
  alias Oban.Web.Workflows.Helpers

  describe "compensation?/1" do
    test "detecting workflows created to roll back another workflow" do
      assert Helpers.compensation?(workflow(meta: %{"origin_id" => "wf-1"}))

      refute Helpers.compensation?(workflow())
      refute Helpers.compensation?(workflow(meta: %{"compensate_on" => ["discarded"]}))
    end
  end

  describe "compensation_policy/1" do
    test "extracting the trigger states from meta" do
      workflow = workflow(meta: %{"compensate_on" => ["discarded"]})

      assert ["discarded"] == Helpers.compensation_policy(workflow)
      assert [] == Helpers.compensation_policy(workflow())
      assert [] == Helpers.compensation_policy(workflow(meta: %{"compensate_on" => []}))
    end
  end

  describe "compensation_status/2" do
    test "reporting no compensation without a policy" do
      assert :none == Helpers.compensation_status(workflow(state: "discarded"))
    end

    test "distinguishing armed from pending by the workflow state" do
      assert :armed == Helpers.compensation_status(policied(state: "executing"))
      assert :armed == Helpers.compensation_status(policied(state: "completed"))

      assert :pending == Helpers.compensation_status(policied(state: "discarded"))
      assert :pending == Helpers.compensation_status(policied(state: "cancelled"))
    end

    test "reporting a resolved family without a compensation as not needed" do
      workflow = policied(state: "completed", resolved_at: DateTime.utc_now())

      assert :not_needed == Helpers.compensation_status(workflow)
    end

    test "tracking a materialized compensation through its own state" do
      root = policied(state: "discarded", compensation_id: "wf-2")

      assert :executing == Helpers.compensation_status(root, workflow(state: "executing"))
      assert :completed == Helpers.compensation_status(root, workflow(state: "completed"))
      assert :failed == Helpers.compensation_status(root, workflow(state: "discarded"))
      assert :failed == Helpers.compensation_status(root, workflow(state: "cancelled"))
    end

    test "reporting a pruned compensation as unknown" do
      root = policied(state: "discarded", compensation_id: "wf-2")

      assert :unknown == Helpers.compensation_status(root, nil)
    end

    test "ignoring resolved_at stamped on a sub-workflow of a compensated family" do
      root =
        policied(state: "discarded", compensation_id: "wf-2", resolved_at: DateTime.utc_now())

      assert :executing == Helpers.compensation_status(root, workflow(state: "executing"))
    end

    test "reporting no compensation for installations without the v1.8 columns" do
      workflow = workflow(state: "discarded", compensation_id: nil, resolved_at: nil)

      assert :none == Helpers.compensation_status(workflow)
    end
  end

  describe "put_compensated_states/2" do
    test "folding compensating job states onto the jobs they roll back" do
      graph = %{jobs: [graph_job(1), graph_job(2), graph_job(3)], sub_workflows: []}

      steps = [
        step(origin_job_id: 1, state: "completed"),
        step(origin_job_id: 3, state: "discarded")
      ]

      assert %{jobs: [first, second, third]} = Helpers.put_compensated_states(graph, steps)

      assert first.meta["compensated"] == "completed"
      assert third.meta["compensated"] == "discarded"

      refute Map.has_key?(second.meta, "compensated")
    end

    test "leaving the graph untouched without any steps" do
      graph = %{jobs: [graph_job(1)], sub_workflows: []}

      assert graph == Helpers.put_compensated_states(graph, [])
    end

    test "ignoring steps whose origin was pruned" do
      graph = %{jobs: [graph_job(1)], sub_workflows: []}

      assert %{jobs: [job]} = Helpers.put_compensated_states(graph, [step(state: "completed")])

      refute Map.has_key?(job.meta, "compensated")
    end
  end

  describe "display_name/1" do
    test "hiding the compensation worker behind a readable name" do
      compensation =
        workflow(name: Helpers.compensation_worker(), meta: %{"origin_id" => "wf-1"})

      assert "Compensation" == Helpers.display_name(compensation)
      assert "my-workflow" == Helpers.display_name(workflow(name: "my-workflow"))
      assert "wf-1" == Helpers.display_name(workflow(id: "wf-1", name: nil))
    end
  end

  defp workflow(opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:id, "wf-1")
      |> Keyword.put_new(:meta, %{})

    struct!(Workflow, opts)
  end

  defp graph_job(id), do: %{id: id, state: "completed", worker: "WorkerA", meta: %{}}

  defp step(opts) do
    meta = %{"origin_job_id" => Keyword.get(opts, :origin_job_id)}

    %{id: 100, state: Keyword.fetch!(opts, :state), meta: meta}
  end

  defp policied(opts) do
    opts
    |> Keyword.put(:meta, %{"compensate_on" => ["discarded", "cancelled"]})
    |> workflow()
  end
end
