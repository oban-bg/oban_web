defmodule Oban.Web.Pages.QueuesTest do
  use Oban.Web.DataCase

  import Phoenix.LiveViewTest

  alias Oban.Web.Plugins.Stats

  setup do
    start_supervised_oban!(plugins: [{Stats, interval: 10}])

    {:ok, live, _html} = live(build_conn(), "/oban/queues")

    {:ok, live: live}
  end

  test "viewing active queues", %{live: live} do
    gossip(node: "web.1", queue: "alpha", limit: 4, paused: false, running: [])
    gossip(node: "web.2", queue: "alpha", limit: 4, paused: false, running: [])
    gossip(node: "web.1", queue: "gamma", limit: 4, paused: false, running: [])

    refresh(live)

    assert has_element?(live, "#queues-header h3", "(2)")

    assert has_element?(live, "#queues-table tr", "alpha")
    assert has_element?(live, "#queues-table tr", "gamma")
  end

  test "expanding queues to see node details", %{live: live} do
    gossip(node: "web.1", queue: "alpha", limit: 4, paused: false, running: [])
    gossip(node: "web.2", queue: "alpha", limit: 4, paused: false, running: [])

    refresh(live)

    expand_queue(live, "alpha")

    assert has_element?(live, "#queue-alpha-node-web_1")
    assert has_element?(live, "#queue-alpha-node-web_2")
  end

  test "pausing and resuming active queues", %{live: live} do
    gossip(node: "web.1", queue: "alpha", limit: 4, paused: false, running: [])
    gossip(node: "web.2", queue: "alpha", limit: 4, paused: false, running: [])

    refresh(live)

    live
    |> element("#queue-alpha button[rel=play_pause]")
    |> render_click()

    expand_queue(live, "alpha")

    live
    |> element("#queue-alpha-node-web_2 button[rel=play_pause]")
    |> render_click()
  end

  test "sorting queues by different properties", %{live: live} do
    gossip(node: "web.1", queue: "alpha", limit: 4, paused: false, running: [])
    gossip(node: "web.1", queue: "gamma", limit: 4, paused: false, running: [])

    refresh(live)

    live
    |> element("#queues-table a[rel=sort]", "local")
    |> render_click()

    assert_patch(live, "/oban/queues?sort=local-desc")
  end

  defp refresh(live) do
    send(live.pid, :refresh)
  end

  defp expand_queue(live, queue) do
    live
    |> element("#queue-#{queue} button[rel=expand]")
    |> render_click()
  end
end
