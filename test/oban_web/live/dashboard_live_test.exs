defmodule ObanWeb.DashboardLiveTest do
  use ObanWeb.DataCase

  import Phoenix.LiveViewTest

  alias Oban.Job
  alias ObanWeb.{DashboardLive, Endpoint, Repo, Stats}

  @stat_opts [queues: [alpha: 1, delta: 1, gamma: 1], repo: Repo]

  setup do
    start_supervised!({Stats, @stat_opts})

    :ok
  end

  describe "viewing jobs in different states" do
    test "viewing available jobs" do
      {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

      insert_job!([ref: 1], worker: FakeWorker)

      assert render_click(view, :change_state, "available") =~ "FakeWorker"
    end

    test "viewing scheduled jobs" do
      {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

      insert_job!([ref: 1], state: "available", worker: RealWorker)
      insert_job!([ref: 2], state: "scheduled", worker: NeueWorker)

      html = render_click(view, :change_state, "scheduled")

      assert html =~ "NeueWorker"
      refute html =~ "RealWorker"
    end

    test "viewing retryable jobs" do
      {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

      insert_job!([ref: 1],
        state: "retryable",
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
  end

  test "filtering jobs by queue" do
    {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker)
    insert_job!([ref: 2], queue: "delta", worker: DeltaWorker)
    insert_job!([ref: 3], queue: "gamma", worker: GammaWorker)

    # None of these are in a running queue, switch to a view where they are visible
    html = render_click(view, :change_state, "available")

    assert html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    assert html =~ "GammaWorker"

    html = render_click(view, :change_queue, "delta")

    refute html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    refute html =~ "GammaWorker"
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
