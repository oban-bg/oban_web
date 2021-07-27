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

  defp refresh(live) do
    send(live.pid, :refresh)
  end
end
