defmodule Oban.Web.Live.FilteringTest do
  use Oban.Web.DataCase

  import Phoenix.LiveViewTest

  alias Oban.Web.Plugins.Stats

  setup do
    start_supervised_oban!(plugins: [Stats])

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live}
  end

  test "viewing available jobs", %{live: live} do
    insert_job!([ref: 1], worker: FakeWorker, state: "available")

    click_state(live, "available")

    assert has_job?(live, "FakeWorker")
    assert has_element?(live, "#jobs-header", "(1/1 Available)")
  end

  test "viewing scheduled jobs", %{live: live} do
    insert_job!([ref: 1], state: "available", worker: RealWorker)
    insert_job!([ref: 2], state: "scheduled", worker: NeueWorker)

    click_state(live, "scheduled")

    assert has_job?(live, "NeueWorker")
    refute has_job?(live, "RealWorker")
  end

  test "viewing retryable jobs", %{live: live} do
    insert_job!([ref: 1], state: "retryable", worker: JankWorker)

    click_state(live, "retryable")

    assert has_job?(live, "JankWorker")
  end

  test "filtering jobs by node", %{live: live} do
    web_1 = ["web-1", "alpha", "aaaaaaaa"]
    web_2 = ["web-2", "alpha", "aaaaaaaa"]

    gossip(node: "web-1", queue: "alpha")
    gossip(node: "web-2", queue: "alpha")

    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker, attempted_by: web_1)
    insert_job!([ref: 2], queue: "alpha", worker: DeltaWorker, attempted_by: web_2)
    insert_job!([ref: 3], queue: "alpha", worker: GammaWorker, attempted_by: web_1)

    click_state(live, "available")

    assert has_job?(live, "AlphaWorker")
    assert has_job?(live, "DeltaWorker")
    assert has_job?(live, "GammaWorker")

    refresh(live)

    click_node(live, "oban_web-2")

    refute has_job?(live, "AlphaWorker")
    assert has_job?(live, "DeltaWorker")
    refute has_job?(live, "GammaWorker")
  end

  test "filtering jobs by queue", %{live: live} do
    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker)
    insert_job!([ref: 2], queue: "delta", worker: DeltaWorker)
    insert_job!([ref: 3], queue: "gamma", worker: GammaWorker)

    click_state(live, "available")

    assert has_job?(live, "AlphaWorker")
    assert has_job?(live, "DeltaWorker")
    assert has_job?(live, "GammaWorker")

    refresh(live)

    click_queue(live, "delta")

    refute has_job?(live, "AlphaWorker")
    assert has_job?(live, "DeltaWorker")
    refute has_job?(live, "GammaWorker")
  end

  @tag :search
  test "filtering jobs by search query", %{live: live} do
    insert_job!([callsign: "yankee"], queue: "alpha", worker: AlphaWorker)
    insert_job!([callsign: "hotel"], queue: "delta", worker: DeltaWorker)
    insert_job!([callsign: "fox trot"], queue: "gamma", worker: GammaWorker)

    click_state(live, "available")

    # Filter down by worker name prefix
    submit_search(live, "delta")

    refute has_job?(live, "AlphaWorker")
    assert has_job?(live, "DeltaWorker")
    refute has_job?(live, "GammaWorker")

    # Filter down by args
    submit_search(live, "fox trot")

    refute has_job?(live, "AlphaWorker")
    refute has_job?(live, "DeltaWorker")
    assert has_job?(live, "GammaWorker")
  end

  test "filtering jobs by worker", %{live: live} do
    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker)
    insert_job!([ref: 2], queue: "delta", worker: DeltaWorker)
    insert_job!([ref: 3], queue: "gamma", worker: GammaWorker)

    click_state(live, "available")

    assert has_job?(live, "AlphaWorker")
    assert has_job?(live, "DeltaWorker")
    assert has_job?(live, "GammaWorker")

    live
    |> element("#listing button[rel='worker-AlphaWorker']")
    |> render_click()

    assert has_job?(live, "AlphaWorker")
    refute has_job?(live, "DeltaWorker")
    refute has_job?(live, "GammaWorker")
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #states #state-#{state}")
    |> render_click()

    refresh(live)
  end

  defp click_node(live, node) do
    live
    |> element("#sidebar #nodes #node-#{node}")
    |> render_click()

    refresh(live)
  end

  defp click_queue(live, queue) do
    live
    |> element("#sidebar #queues #queue-#{queue}")
    |> render_click()

    refresh(live)
  end

  defp submit_search(live, terms) do
    live
    |> element("#search")
    |> render_change(%{terms: terms})

    refresh(live)
  end

  defp has_job?(live, worker_name) do
    has_element?(live, "#listing", worker_name)
  end

  defp refresh(live) do
    Oban
    |> Oban.Registry.whereis({:plugin, Stats})
    |> send(:refresh)

    Process.sleep(10)

    send(live.pid, :refresh)
  end
end
