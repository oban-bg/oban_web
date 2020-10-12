defmodule Oban.Web.Live.FilteringTest do
  use Oban.Web.DataCase

  import Phoenix.LiveViewTest

  alias Oban.Web.Plugins.Stats

  @name Oban

  setup do
    start_supervised_oban!(plugins: [Stats])

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live}
  end

  test "viewing available jobs", %{live: live} do
    insert_job!([ref: 1], worker: FakeWorker, state: "available")

    assert click_state(live, "available") =~ "FakeWorker"
  end

  test "viewing scheduled jobs", %{live: live} do
    insert_job!([ref: 1], state: "available", worker: RealWorker)
    insert_job!([ref: 2], state: "scheduled", worker: NeueWorker)

    html = click_state(live, "scheduled")

    assert html =~ "NeueWorker"
    refute html =~ "RealWorker"
  end

  test "viewing retryable jobs", %{live: live} do
    insert_job!([ref: 1], state: "retryable", worker: JankWorker)

    assert click_state(live, "retryable") =~ "JankWorker"
  end

  test "filtering jobs by node", context do
    web_1 = ["web-1", "alpha", "aaaaaaaa"]
    web_2 = ["web-2", "alpha", "aaaaaaaa"]

    insert_beat!(node: "web-1")
    insert_beat!(node: "web-2")

    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker, attempted_by: web_1)
    insert_job!([ref: 2], queue: "alpha", worker: DeltaWorker, attempted_by: web_2)
    insert_job!([ref: 3], queue: "alpha", worker: GammaWorker, attempted_by: web_1)

    html = click_state(context.live, "available")

    assert html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    assert html =~ "GammaWorker"

    refresh(context)

    html = click_node(context.live, "web-2")

    refute html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    refute html =~ "GammaWorker"
  end

  test "filtering jobs by queue", context do
    insert_beat!(node: "web.1", queue: "delta")

    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker)
    insert_job!([ref: 2], queue: "delta", worker: DeltaWorker)
    insert_job!([ref: 3], queue: "gamma", worker: GammaWorker)

    html = click_state(context.live, "available")

    assert html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    assert html =~ "GammaWorker"

    refresh(context)

    html = click_queue(context.live, "delta")

    refute html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    refute html =~ "GammaWorker"
  end

  test "filtering jobs by search query", %{live: live} do
    insert_job!([callsign: "yankee"], queue: "alpha", worker: AlphaWorker)
    insert_job!([callsign: "hotel"], queue: "delta", worker: DeltaWorker)
    insert_job!([callsign: "fox trot"], queue: "gamma", worker: GammaWorker)

    click_state(live, "available")

    # Filter down by worker name prefix
    html = submit_search(live, "delta")

    refute html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    refute html =~ "GammaWorker"

    # Filter down by args
    html = submit_search(live, "fox trot")

    refute html =~ "AlphaWorker"
    refute html =~ "DeltaWorker"
    assert html =~ "GammaWorker"
  end

  test "filtering jobs by worker", %{live: live} do
    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker)
    insert_job!([ref: 2], queue: "delta", worker: DeltaWorker)
    insert_job!([ref: 3], queue: "gamma", worker: GammaWorker)

    html = click_state(live, "available")

    assert html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    assert html =~ "GammaWorker"

    live
    |> element("#listing button[rel='worker-AlphaWorker']")
    |> render_click()

    html = render(live)

    assert html =~ "AlphaWorker"
    refute html =~ "DeltaWorker"
    refute html =~ "GammaWorker"
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #states #state-#{state}")
    |> render_click()

    render(live)
  end

  defp click_node(live, node) do
    live
    |> element("#sidebar #nodes #node-#{node}")
    |> render_click()

    render(live)
  end

  defp click_queue(live, queue) do
    live
    |> element("#sidebar #queues #queue-#{queue}")
    |> render_click()

    render(live)
  end

  defp submit_search(live, terms) do
    live
    |> element("#search")
    |> render_change(%{terms: terms})

    render(live)
  end

  defp refresh(%{live: live}) do
    @name
    |> Oban.Registry.whereis({:plugin, Stats})
    |> send(:refresh)

    Process.sleep(10)

    send(live.pid, :refresh)
  end
end
