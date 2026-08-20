defmodule Oban.Web.Pages.Workflows.IndexTest do
  use Oban.Web.Case

  alias Oban.Web.{CompensationFixture, Workflow}
  alias Oban.Web.Workflows.Helpers

  @moduletag :pro

  @compile {:no_warn_undefined, Oban.Web.CompensationFixture}

  setup do
    name = start_supervised_oban!(engine: Oban.Pro.Engine)

    {:ok, live, _html} = live(build_conn(), "/oban/workflows")

    {:ok, conf: Oban.config(name), live: live}
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

  test "naming compensation workflows after the workflow they roll back", %{
    conf: conf,
    live: live
  } do
    saga = CompensationFixture.insert_compensated_saga!(conf, name: "order-fulfillment")

    refresh(live)

    assert has_element?(live, "#workflow-#{saga.compensation_id}", "order-fulfillment")
    assert has_element?(live, "#workflow-#{saga.compensation_id}", "Compensation")

    refute has_element?(live, "#workflow-#{saga.compensation_id}", Helpers.compensation_worker())
    refute has_element?(live, "#workflow-#{saga.id}", "Compensation")
  end

  test "falling back to the origin id once the origin is pruned", %{conf: conf, live: live} do
    saga = CompensationFixture.insert_compensated_saga!(conf, name: "order-fulfillment")

    Repo.delete_all(where(Workflow, id: ^saga.id))

    refresh(live)

    assert has_element?(live, "#workflow-#{saga.compensation_id}", saga.id)
  end

  defp insert_workflow!(workflow_id, opts) do
    {queues, opts} = Keyword.pop(opts, :queues, ["default"])
    {workers, opts} = Keyword.pop(opts, :workers, ["TestWorker"])
    {meta, opts} = Keyword.pop(opts, :meta, %{})

    others = Map.new(opts)

    params = %{
      id: workflow_id,
      inserted_at: DateTime.utc_now(),
      meta: Map.merge(%{"queues" => queues, "workers" => workers}, meta)
    }

    params
    |> Map.merge(others)
    |> Workflow.changeset()
    |> Repo.insert!()
  end
end
