defmodule ObanWeb.DashboardLiveTest do
  use ObanWeb.DataCase

  import Phoenix.LiveViewTest

  alias Oban.Job
  alias ObanWeb.{Repo, Stats}

  @stat_opts [queues: [alpha: 1, delta: 1, gamma: 1], repo: Repo]

  setup do
    start_supervised!({Stats, @stat_opts})

    {:ok, conn: build_conn()}
  end

  describe "viewing jobs in different states" do
    test "viewing available jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/oban")

      insert_job!([ref: 1], worker: FakeWorker)

      assert render_click(view, :change_state, %{"state" => "available"}) =~ "FakeWorker"
    end

    test "viewing scheduled jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/oban")

      insert_job!([ref: 1], state: "available", worker: RealWorker)
      insert_job!([ref: 2], state: "scheduled", worker: NeueWorker)

      html = render_click(view, :change_state, %{"state" => "scheduled"})

      assert html =~ "NeueWorker"
      refute html =~ "RealWorker"
    end

    test "viewing retryable jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/oban")

      insert_job!([ref: 1],
        state: "retryable",
        worker: JankWorker,
        errors: [%{attempt: 1, at: DateTime.utc_now(), error: "Formatted RuntimeError"}]
      )

      html = render_click(view, :change_state, %{"state" => "retryable"})

      assert html =~ "JankWorker"
    end

    test "viewing discarded jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/oban")

      insert_job!([ref: 1], state: "available", worker: RealWorker)
      insert_job!([ref: 2], state: "discarded", worker: DeadWorker)

      html = render_click(view, :change_state, %{"state" => "discarded"})

      assert html =~ "DeadWorker"
      refute html =~ "RealWorker"
    end

    test "paging through availble jobs", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/oban")

      insert_job!([ref: 1], worker: FakeWorker)

      assert render_click(view, :change_state, %{"state" => "available"}) =~ "FakeWorker"
    end
  end

  test "filtering jobs by node", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/oban")

    web_1 = ["web.1", "alpha", "aaaaaaaa"]
    web_2 = ["web.2", "alpha", "aaaaaaaa"]

    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker, attempted_by: web_1)
    insert_job!([ref: 2], queue: "alpha", worker: DeltaWorker, attempted_by: web_2)
    insert_job!([ref: 3], queue: "alpha", worker: GammaWorker, attempted_by: web_1)

    html = render_click(view, :change_state, %{"state" => "available"})

    assert html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    assert html =~ "GammaWorker"

    html = render_click(view, :change_node, %{"node" => "web.2"})

    refute html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    refute html =~ "GammaWorker"
  end

  test "filtering jobs by queue", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/oban")

    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker)
    insert_job!([ref: 2], queue: "delta", worker: DeltaWorker)
    insert_job!([ref: 3], queue: "gamma", worker: GammaWorker)

    # None of these are in a running queue, switch to a view where they are visible
    html = render_click(view, :change_state, %{"state" => "available"})

    assert html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    assert html =~ "GammaWorker"

    html = render_click(view, :change_queue, %{"queue" => "delta"})

    refute html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    refute html =~ "GammaWorker"
  end

  test "filtering jobs by search query", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/oban")

    insert_job!([callsign: "yankee"], queue: "alpha", worker: AlphaWorker)
    insert_job!([callsign: "hotel"], queue: "delta", worker: DeltaWorker)
    insert_job!([callsign: "foxtrot"], queue: "gamma", worker: GammaWorker)

    # None of these are in a running queue, switch to a view where they are visible
    render_click(view, :change_state, %{"state" => "available"})

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

  test "killing an executing job", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/oban")

    html = render_click(view, :kill_job, %{"id" => "123"})

    assert html =~ ~S|<div class="blitz blitz--show">|
    assert html =~ ~S|<span class="blitz__message">Job canceled and discarded.</span>|

    html = render_click(view, :blitz_close, "")

    assert html =~ ~S|<div class="blitz ">|
  end

  test "deleting a job", %{conn: conn} do
    %Job{id: jid} = insert_job!([ref: 1], worker: FakeWorker)

    {:ok, view, _html} = live(conn, "/oban")

    html = render_click(view, :delete_job, %{"id" => to_string(jid)})

    assert html =~ ~S|<div class="blitz blitz--show">|
    assert html =~ ~S|<span class="blitz__message">Job deleted.</span>|
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
