defmodule ObanWeb.DashboardLiveTest do
  use ObanWeb.DataCase

  import Phoenix.LiveViewTest

  alias Oban.Job
  alias ObanWeb.{DashboardLive, Endpoint, Repo}

  test "simple mounting" do
    {:ok, _view, html} = mount(Endpoint, DashboardLive, session: %{})

    assert html =~ "Executing Jobs"
  end

  test "viewing available jobs" do
    {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

    insert_job!([ref: 1], worker: FakeWorker)

    assert render_click(view, :change_state, "available") =~ "FakeWorker"
  end

  test "viewing scheduled jobs" do
    {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

    insert_job!([ref: 1], state: "available", worker: RealWorker)
    insert_job!([ref: 2], scheduled_in: 5, state: "available", worker: NeueWorker)

    html = render_click(view, :change_state, "scheduled")

    assert html =~ "NeueWorker"
    refute html =~ "RealWorker"
  end

  test "viewing retryable jobs" do
    {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

    insert_job!([ref: 1],
      scheduled_in: 5,
      state: "available",
      attempt: 1,
      worker: JankWorker,
      errors: [%{attempt: 1, at: DateTime.utc_now(), error: "Formatted RuntimeError"}]
    )

    html = render_click(view, :change_state, "retryable")

    assert html =~ "JankWorker"
    assert html =~ "Formatted RuntimeError"
  end

  test "viewing discarded jobs" do
    {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

    insert_job!([ref: 1], state: "available", worker: RealWorker)
    insert_job!([ref: 2], state: "discarded", worker: DeadWorker)

    html = render_click(view, :change_state, "discarded")

    assert html =~ "DeadWorker"
    refute html =~ "RealWorker"
  end

  defp insert_job!(args, opts) do
    opts =
      opts
      |> Keyword.put_new(:queue, :special)
      |> Keyword.put_new(:worker, FakeWorker)

    args
    |> Map.new()
    |> Job.new(opts)
    |> Repo.insert!()
  end
end
