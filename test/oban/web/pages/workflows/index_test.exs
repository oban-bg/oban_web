defmodule Oban.Web.Pages.Workflows.IndexTest do
  use Oban.Web.Case

  alias Oban.Web.Workflow

  @moduletag :pro

  setup do
    start_supervised_oban!()

    {:ok, live, _html} = live(build_conn(), "/oban/workflows")

    {:ok, live: live}
  end

  test "displays empty state when no workflows exist", %{live: live} do
    refresh(live)

    html = render(live)

    assert html =~ "No workflows"
    assert html =~ "Workflows coordinate jobs with dependencies"
  end

  test "displays workflow name and queues", %{live: live} do
    insert_workflow!("wf-order", name: "order-fulfillment", queues: ["default", "media"])

    refresh(live)

    html = render(live)

    assert html =~ "order-fulfillment"
    assert html =~ "default"
    assert html =~ "media"
  end

  test "displays workflow progress counts", %{live: live} do
    insert_workflow!("wf-progress", completed: 5, executing: 2, available: 3)

    refresh(live)

    html = render(live)

    assert html =~ "5/10"
  end

  test "clicking a workflow navigates to detail view", %{live: live} do
    insert_workflow!("wf-clickable", name: "clickable-workflow", scheduled: 1)

    refresh(live)

    live
    |> element("#workflow-wf-clickable a")
    |> render_click()

    assert_patch(live, "/oban/workflows/wf-clickable")
  end

  defp refresh(live) do
    send(live.pid, :refresh)

    render(live)
  end

  defp insert_workflow!(workflow_id, opts) do
    {queues, opts} = Keyword.pop(opts, :queues, ["default"])
    {workers, opts} = Keyword.pop(opts, :workers, ["TestWorker"])

    others = Map.new(opts)

    params = %{
      id: workflow_id,
      inserted_at: DateTime.utc_now(),
      meta: %{"queues" => queues, "workers" => workers}
    }

    params
    |> Map.merge(others)
    |> Workflow.changeset()
    |> Repo.insert!()
  end
end
