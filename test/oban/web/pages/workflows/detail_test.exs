defmodule Oban.Web.Pages.Workflows.DetailTest do
  use Oban.Web.Case

  alias Oban.Web.{CompensationFixture, Workflow}

  @moduletag :pro

  @compile {:no_warn_undefined, Oban.Web.CompensationFixture}

  setup do
    name = start_supervised_oban!(engine: Oban.Pro.Engine)

    {:ok, conf: Oban.config(name)}
  end

  test "displays not found for missing workflow" do
    {:ok, live, _html} = live(build_conn(), "/oban/workflows/nonexistent-wf")

    assert refresh(live) =~ "Workflow not found"
  end

  test "displays workflow details" do
    insert_workflow!("wf-detail",
      name: "my-workflow",
      queues: ["alpha", "beta"],
      completed: 5,
      executing: 2,
      available: 3
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
    insert_workflow!("wf-parent", name: "parent-workflow", completed: 1)
    insert_workflow!("wf-child", parent_id: "wf-parent", name: "child-workflow", completed: 1)

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
    insert_workflow!("wf-buttons", executing: 1, retryable: 1)

    {:ok, live, _html} = live(build_conn(), "/oban/workflows/wf-buttons")

    refresh(live)

    assert has_element?(live, "#detail-cancel")
    assert has_element?(live, "#detail-retry")
  end

  test "displaying compensation status on a failed workflow", %{conf: conf} do
    saga = CompensationFixture.insert_compensated_saga!(conf, name: "order-fulfillment")

    {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

    refresh(live)

    assert has_element?(live, "#comp-toggle", "Compensation")
    assert has_element?(live, "#comp-toggle", "Executing")
    assert has_element?(live, "#compensation-detail", "Triggers On")
    assert has_element?(live, "#compensation-detail", "discarded")
    assert has_element?(live, "#compensation-link")
  end

  test "distinguishing an armed workflow from a pending one", %{conf: conf} do
    armed = CompensationFixture.insert_saga!(conf)
    pending = CompensationFixture.insert_failed_saga!(conf)

    {:ok, armed_live, _html} = live(build_conn(), "/oban/workflows/#{armed.id}")

    refresh(armed_live)

    assert has_element?(armed_live, "#comp-toggle", "Armed")
    refute has_element?(armed_live, "#compensation-link")

    {:ok, pending_live, _html} = live(build_conn(), "/oban/workflows/#{pending.id}")

    refresh(pending_live)

    assert has_element?(pending_live, "#comp-toggle", "Pending")
  end

  test "omitting the compensation section without a policy" do
    insert_workflow!("wf-plain", completed: 1)

    {:ok, live, _html} = live(build_conn(), "/oban/workflows/wf-plain")

    refresh(live)

    refute has_element?(live, "#comp-toggle")
  end

  test "linking a compensation workflow back to its origin", %{conf: conf} do
    saga = CompensationFixture.insert_compensated_saga!(conf, name: "order-fulfillment")

    {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.compensation_id}")

    refresh(live)

    assert has_element?(live, "#back-link", "Compensation")
    assert has_element?(live, "#origin-breadcrumb", "compensating")
    assert has_element?(live, "#origin-breadcrumb", "order-fulfillment")
  end

  test "enabling retry only for a failed compensation", %{conf: conf} do
    saga = CompensationFixture.insert_compensated_saga!(conf)

    CompensationFixture.finish_compensation!(conf, saga, "discarded")

    {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

    refresh(live)

    assert has_element?(live, "#comp-toggle", "Failed")
    assert has_element?(live, "#comp-retry:not([disabled])")
    assert has_element?(live, "#comp-cancel[disabled]")
  end

  test "listing compensation steps with the workers they roll back", %{conf: conf} do
    saga = CompensationFixture.insert_compensated_saga!(conf)

    {:ok, live, _html} = live(build_conn(), "/oban/workflows/#{saga.id}")

    refresh(live)

    assert has_element?(live, "#compensation-detail", "charge")
    assert has_element?(live, "#compensation-detail", "ChargeCard")
  end

  test "marking graph nodes that were rolled back", %{conf: conf} do
    saga = CompensationFixture.insert_compensated_saga!(conf)

    CompensationFixture.finish_compensation!(conf, saga, "completed")

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
