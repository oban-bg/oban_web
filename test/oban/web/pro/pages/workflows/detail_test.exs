if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Workflows.DetailTest do
    use Oban.Web.ProCase, async: true

    setup do
      {:ok, oban: start_supervised_oban!()}
    end

    test "displays not found for missing workflow" do
      {:ok, live, _html} = live(build_conn(), "/oban/workflows/nonexistent-wf")

      assert refresh(live) =~ "Workflow not found"
      assert has_element?(live, "#workflow-not-found", "nonexistent-wf")
      assert has_element?(live, "#not-found-back", "Back to workflows")
    end

    test "displays workflow details", %{oban: oban} do
      # Five steps complete and five snooze, leaving them scheduled
      run_workflow!(
        oban,
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

      assert has_element?(live, "h2 #back-link", "my-workflow")
      assert has_element?(live, "#status-state", "Executing")
      assert has_element?(live, "#workflow-progress", "50% Complete")
      assert has_element?(live, "#workflow-progress", "5/10 jobs")
      assert has_element?(live, "#legend-completed", "Completed 5")
      assert has_element?(live, "#legend-scheduled", "Scheduled 5")
      assert has_element?(live, "#workflow-stats", "alpha")
      assert has_element?(live, "#workflow-stats", "beta")
      assert has_element?(live, "#subs-none", "none")
    end

    test "labelling collapsible sections for assistive tech", %{oban: oban} do
      run_workflow!(oban, workflow_id: "wf-sections")

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/wf-sections")

      refresh(live)

      assert has_element?(
               live,
               ~s|h3 #graph-toggle[aria-expanded="true"][aria-controls="workflow-graph"]|
             )

      assert has_element?(live, ~s|#toggle-tracking[aria-pressed="true"][aria-label]|)

      live
      |> element("#graph-toggle")
      |> render_click()

      assert has_element?(live, ~s|#graph-toggle[aria-expanded="false"]|)
      refute has_element?(live, "#workflow-graph")
    end

    test "displays sub-workflow relationships", %{oban: oban} do
      insert_workflow!(oban,
        workflow_id: "wf-parent",
        workflow_name: "parent-workflow",
        subs: [[workflow_id: "wf-child", workflow_name: "child-workflow"]]
      )

      {:ok, parent_live, _html} = live(build_conn(), "/oban/workflows/wf-parent")

      refresh(parent_live)

      assert has_element?(parent_live, "#subs-toggle", "Sub-workflows")
      assert has_element?(parent_live, "#subs-toggle", "(1)")
      assert has_element?(parent_live, "#sub-workflow-wf-child a", "child-workflow")
      assert has_element?(parent_live, "#sub-workflow-wf-child-state .sr-only")
      refute has_element?(parent_live, "#subs-none")

      {:ok, child_live, _html} = live(build_conn(), "/oban/workflows/wf-child")

      refresh(child_live)

      assert has_element?(child_live, "#workflow-stats", "Parent Workflow")
      assert has_element?(child_live, "#parent-link", "parent-workflow")
    end

    test "confirming before cancelling unfinished jobs", %{oban: oban} do
      insert_workflow!(oban,
        workflow_id: "wf-cancel",
        workflow_name: "cancel-me",
        steps: [[], []]
      )

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/wf-cancel")

      refresh(live)

      assert has_element?(
               live,
               ~s|#detail-cancel:not([disabled])[data-confirm^="Cancel 2 unfinished jobs in cancel-me?"]|
             )

      assert has_element?(live, "#detail-retry[disabled]")

      live
      |> element("#detail-cancel")
      |> render_click()

      assert has_element?(live, "#notice", "Cancelled 2 jobs in cancel-me")
      assert has_element?(live, "#status-state", "Cancelled")
      assert has_element?(live, "#detail-cancel[disabled]")
      assert has_element?(live, "#detail-retry:not([disabled])")
    end

    test "disabling cancel once every job has finished", %{oban: oban} do
      run_workflow!(oban, workflow_id: "wf-finished")

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/wf-finished")

      refresh(live)

      assert has_element?(live, "#status-state", "Completed")
      assert has_element?(live, "#detail-cancel[disabled]")
      assert has_element?(live, "#detail-retry[disabled]")
    end

    test "warning that a retry re-runs rolled back steps", %{oban: oban} do
      saga = compensate_saga!(run_failed_saga!(oban))

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert has_element?(live, "#status-state", "Discarded")
      assert has_element?(live, "#detail-cancel[disabled]")

      assert has_element?(
               live,
               ~s|#detail-retry:not([disabled])[data-confirm*="Its rollback already ran"]|
             )
    end

    test "displaying compensation status on a failed workflow", %{oban: oban} do
      saga = run_failed_saga!(oban, workflow_name: "order-fulfillment")

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert has_element?(live, "#comp-toggle", "Compensation")
      assert has_element?(live, "#comp-toggle", "Executing")
      assert has_element?(live, "#compensation-detail", "Triggers On")
      assert has_element?(live, "#compensation-detail", "discarded")
      assert has_element?(live, "#compensation-link")
    end

    test "showing an armed policy before the workflow fails", %{oban: oban} do
      saga = insert_saga!(oban)

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert has_element?(live, "#comp-toggle", "Armed")
      assert has_element?(live, ~s|#comp-status[data-title*="if any job ends up discarded"]|)
      refute has_element?(live, "#compensation-link")
    end

    test "omitting the compensation section without a policy", %{oban: oban} do
      run_workflow!(oban, workflow_id: "wf-plain")

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/wf-plain")

      refresh(live)

      refute has_element?(live, "#comp-toggle")
    end

    test "linking a compensation workflow back to its origin", %{oban: oban} do
      saga = run_failed_saga!(oban, workflow_name: "order-fulfillment")

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.compensation_id}")

      refresh(live)

      assert has_element?(live, "#back-link", "Compensation")
      assert has_element?(live, "#status-compensation", "Compensation")
      assert has_element?(live, "#workflow-stats", "Rolls Back")
      assert has_element?(live, "#origin-link", "order-fulfillment")
    end

    test "enabling retry only for a failed compensation", %{oban: oban} do
      saga =
        oban
        |> run_failed_saga!(charge_args: %{refund: "error"})
        |> compensate_saga!()

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert has_element?(live, "#comp-toggle", "Failed")
      assert has_element?(live, "#comp-retry:not([disabled])")
      assert has_element?(live, "#comp-cancel[disabled]")
    end

    test "listing compensation steps with the workers they roll back", %{oban: oban} do
      saga = run_failed_saga!(oban)

      {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

      refresh(live)

      assert has_element?(live, "#compensation-detail", "charge")
      assert has_element?(live, "#compensation-detail", "ChargeCard")
    end

    test "marking graph nodes that were rolled back", %{oban: oban} do
      saga = compensate_saga!(run_failed_saga!(oban))

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
