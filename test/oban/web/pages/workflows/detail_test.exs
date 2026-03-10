defmodule Oban.Web.Pages.Workflows.DetailTest do
  use Oban.Web.Case

  alias Oban.Web.Workflow

  @moduletag :pro

  setup do
    start_supervised_oban!()

    :ok
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
