if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Workflows.DetailTest do
    use Oban.Web.ProCase

    setup do
      start_supervised_oban!()

      :ok
    end

    test "displays not found for missing workflow" do
      {:ok, live, _html} = live(build_conn(), "/oban/workflows/nonexistent-wf")

      assert refresh(live) =~ "Workflow not found"
    end

    test "displays workflow details" do
      # Five steps complete and five snooze, leaving them scheduled
      run_workflow!(
        [
          workflow_id: "wf-detail",
          workflow_name: "my-workflow",
          steps:
            List.duplicate([queue: "alpha"], 5) ++
              List.duplicate([queue: "beta", args: %{result: "snooze"}], 5)
        ],
        with_scheduled: false
      )

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/wf-detail")

      refresh(live)

      assert has_element?(live, "#back-link", "my-workflow")
      assert has_element?(live, "#workflow-progress", "50% Complete")
      assert has_element?(live, "#workflow-progress", "5/10 jobs")
      assert has_element?(live, "#workflow-stats", "executing")
      assert has_element?(live, "#workflow-stats", "alpha")
      assert has_element?(live, "#workflow-stats", "beta")
    end

    test "displays sub-workflow relationships" do
      insert_workflow!(
        workflow_id: "wf-parent",
        workflow_name: "parent-workflow",
        subs: [[workflow_id: "wf-child", workflow_name: "child-workflow"]]
      )

      {:ok, parent_live, _html} = live(build_conn(), "/oban/workflows/wf-parent")

      refresh(parent_live)

      assert has_element?(parent_live, "#subs-toggle", "Sub-workflows")
      assert has_element?(parent_live, "#subs-toggle", "(1)")
      assert has_element?(parent_live, "#workflow-details", "child-workflow")

      {:ok, child_live, _html} = live(build_conn(), "/oban/workflows/wf-child")

      refresh(child_live)

      assert has_element?(child_live, "#workflow-details", "sub-workflow of")
      assert has_element?(child_live, "#workflow-details", "parent-workflow")
    end

    test "has cancel and retry buttons" do
      insert_workflow!(workflow_id: "wf-buttons")

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/wf-buttons")

      refresh(live)

      assert has_element?(live, "#detail-cancel")
      assert has_element?(live, "#detail-retry")
    end

    test "displaying compensation status on a failed workflow" do
      saga = run_failed_saga!(workflow_name: "order-fulfillment")

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert has_element?(live, "#comp-toggle", "Compensation")
      assert has_element?(live, "#comp-toggle", "Executing")
      assert has_element?(live, "#compensation-detail", "Triggers On")
      assert has_element?(live, "#compensation-detail", "discarded")
      assert has_element?(live, "#compensation-link")
    end

    test "showing an armed policy before the workflow fails" do
      saga = insert_saga!()

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert has_element?(live, "#comp-toggle", "Armed")
      refute has_element?(live, "#compensation-link")
    end

    test "omitting the compensation section without a policy" do
      run_workflow!(workflow_id: "wf-plain")

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/wf-plain")

      refresh(live)

      refute has_element?(live, "#comp-toggle")
    end

    test "linking a compensation workflow back to its origin" do
      saga = run_failed_saga!(workflow_name: "order-fulfillment")

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.compensation_id}")

      refresh(live)

      assert has_element?(live, "#back-link", "Compensation")
      assert has_element?(live, "#origin-breadcrumb", "compensating")
      assert has_element?(live, "#origin-breadcrumb", "order-fulfillment")
    end

    test "enabling retry only for a failed compensation" do
      saga =
        [charge_args: %{refund: "error"}]
        |> run_failed_saga!()
        |> compensate_saga!()

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert has_element?(live, "#comp-toggle", "Failed")
      assert has_element?(live, "#comp-retry:not([disabled])")
      assert has_element?(live, "#comp-cancel[disabled]")
    end

    test "listing compensation steps with the workers they roll back" do
      saga = run_failed_saga!()

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert has_element?(live, "#compensation-detail", "charge")
      assert has_element?(live, "#compensation-detail", "ChargeCard")
    end

    test "marking graph nodes that were rolled back" do
      saga = compensate_saga!(run_failed_saga!())

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert_push_event(live, "graph-data", %{jobs: jobs})

      charge = Enum.find(jobs, &(&1.meta["name"] == "charge"))
      ship = Enum.find(jobs, &(&1.meta["name"] == "ship"))

      assert charge.meta["compensated"] == "completed"
      assert charge.meta["compensate"]["kind"] == "worker"

      refute ship.meta["compensated"]
    end

    defp refresh(live) do
      send(live.pid, :refresh)

      render(live)
    end
  end
end
