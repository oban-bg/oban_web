if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Workflows.IndexTest do
    use Oban.Web.ProCase, async: true

    alias Oban.Web.Workflow
    alias Oban.Web.Workflows.Helpers

    setup do
      oban = start_supervised_oban!()

      {:ok, live, _html} = live(build_conn(), "/oban/workflows")

      {:ok, live: live, oban: oban}
    end

    test "displays empty state when no workflows exist", %{live: live} do
      html = refresh(live)

      assert html =~ "No workflows"
      assert html =~ "Workflows coordinate jobs with dependencies"
    end

    test "displays workflow name and queues", %{live: live, oban: oban} do
      insert_workflow!(oban,
        workflow_id: "wf-order",
        workflow_name: "order-fulfillment",
        steps: [[queue: "default"], [queue: "media"]]
      )

      html = refresh(live)

      assert html =~ "order-fulfillment"
      assert html =~ "default"
      assert html =~ "media"
    end

    test "displays workflow progress counts", %{live: live, oban: oban} do
      # Five steps complete and five snooze, leaving them scheduled
      run_workflow!(
        oban,
        [
          workflow_id: "wf-progress",
          steps: List.duplicate([], 5) ++ List.duplicate([args: %{result: "snooze"}], 5)
        ],
        with_scheduled: false
      )

      html = refresh(live)

      assert html =~ "5/10"
    end

    test "clicking a workflow navigates to detail view", %{live: live, oban: oban} do
      insert_workflow!(oban, workflow_id: "wf-clickable", workflow_name: "clickable-workflow")

      refresh(live)

      live
      |> element("#workflow-wf-clickable a")
      |> render_click()

      assert_patch(live, "/oban/workflows/wf-clickable")
    end

    test "naming compensation workflows after the workflow they roll back", %{
      live: live,
      oban: oban
    } do
      saga = run_failed_saga!(oban, workflow_name: "order-fulfillment")

      refresh(live)

      assert has_element?(live, "#workflow-#{saga.compensation_id}", "order-fulfillment")
      assert has_element?(live, "#workflow-#{saga.compensation_id}", "Compensation")

      refute has_element?(
               live,
               "#workflow-#{saga.compensation_id}",
               Helpers.compensation_worker()
             )

      refute has_element?(live, "#workflow-#{saga.id}", "Compensation")
    end

    test "falling back to the origin id once the origin is pruned", %{live: live, oban: oban} do
      saga = run_failed_saga!(oban, workflow_name: "order-fulfillment")

      Repo.delete_all(where(Workflow, id: ^saga.id))

      refresh(live)

      assert has_element?(live, "#workflow-#{saga.compensation_id}", saga.id)
    end

    defp refresh(live) do
      send(live.pid, :refresh)

      render(live)
    end
  end
end
