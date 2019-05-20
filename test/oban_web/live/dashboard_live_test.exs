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

  test "filtering jobs by search query" do
    {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

    insert_job!([callsign: "yankee"], queue: "alpha", worker: AlphaWorker)
    insert_job!([callsign: "hotel"], queue: "delta", worker: DeltaWorker)
    insert_job!([callsign: "foxtrot"], queue: "gamma", worker: GammaWorker)

    # None of these are in a running queue, switch to a view where they are visible
    render_click(view, :change_state, "available")

    # Filter down by worker name prefix
    html = render_change(view, :change_terms, %{terms: "delta"})

    refute html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    refute html =~ "GammaWorker"

    # Filter down by worker name fuzzy match
    html = render_change(view, :change_terms, %{terms: "elphawor"})

    assert html =~ "AlphaWorker"
    refute html =~ "DeltaWorker"
    refute html =~ "GammaWorker"

    # Filter down by args
    html = render_change(view, :change_terms, %{terms: "foxtrot"})

    refute html =~ "AlphaWorker"
    refute html =~ "DeltaWorker"
    assert html =~ "GammaWorker"
  end

  test "killing an executing job" do
    {:ok, view, _html} = mount(Endpoint, DashboardLive, session: %{})

    html = render_click(view, :kill_job, "123")

    assert html =~ ~S|<div class="blitz blitz--show">|
    assert html =~ ~S|<span class="blitz__message">Job canceled and discarded.</span>|

    html = render_click(view, :blitz_close, "")

    assert html =~ ~S|<div class="blitz ">|
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
