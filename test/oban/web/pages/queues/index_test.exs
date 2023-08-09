defmodule Oban.Web.Pages.Queues.IndexTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  setup do
    start_supervised_oban!()

    {:ok, live, _html} = live(build_conn(), "/oban/queues")

    {:ok, live: live}
  end

  test "viewing active queues", %{live: live} do
    gossip(node: "web.1", queue: "alpha")
    gossip(node: "web.2", queue: "alpha")
    gossip(node: "web.1", queue: "gamma")

    refresh(live)

    assert has_element?(live, "#queues-header h3", "(2)")
    assert has_element?(live, "#queues-table tr", "alpha")
    assert has_element?(live, "#queues-table tr", "gamma")
  end

  test "expanding queues to see node details", %{live: live} do
    gossip(node: "web.1", queue: "alpha")
    gossip(node: "web.2", queue: "alpha")

    refresh(live)

    expand_queue(live, "alpha")

    assert has_element?(live, "#queue-alpha-node-web_1")
    assert has_element?(live, "#queue-alpha-node-web_2")
  end

  test "viewing aggregate rate-limit details", %{live: live} do
    rate_limit = %{
      allowed: 10,
      period: 60,
      window_time: time_iso_now(),
      windows: [%{curr_count: 3, prev_count: 0}]
    }

    gossip(node: "web.1", queue: "alpha", rate_limit: rate_limit)
    gossip(node: "web.2", queue: "alpha", rate_limit: rate_limit)

    refresh(live)

    assert has_element?(live, "#queue-alpha [rel=rate]", "6/10 per 1m")

    expand_queue(live, "alpha")

    assert has_element?(live, "#queue-alpha-node-web_1 [rel=rate]", "3/10 per 1m")
    assert has_element?(live, "#queue-alpha-node-web_2 [rel=rate]", "3/10 per 1m")
  end

  test "pausing and resuming active queues", %{live: live} do
    gossip(node: "web.1", queue: "alpha")
    gossip(node: "web.2", queue: "alpha")

    refresh(live)

    live
    |> element("#queue-alpha button[rel=toggle-pause]")
    |> render_click()

    expand_queue(live, "alpha")

    live
    |> element("#queue-alpha-node-web_2 button[rel=toggle-pause]")
    |> render_click()
  end

  test "sorting queues by different properties", %{live: live} do
    rate_limit = %{
      allowed: 10,
      period: 60,
      window_time: time_iso_now(),
      windows: [%{curr_count: 3, prev_count: 0}]
    }

    gossip(node: "web.1", queue: "alpha")
    gossip(node: "web.1", queue: "gamma", rate_limit: rate_limit)

    refresh(live)

    for mode <- ~w(nodes exec avail local global started) do
      change_sort(live, mode)

      assert_patch(live, queues_path(sort_by: mode, sort_dir: "asc"))
    end

    change_sort(live, "rate limit")
    assert_patch(live, queues_path(sort_by: "rate_limit", sort_dir: "asc"))

    change_sort(live, "rate limit")
    assert_patch(live, queues_path(sort_by: "rate_limit", sort_dir: "desc"))
  end

  defp queues_path(params) do
    "/oban/queues?#{URI.encode_query(params)}"
  end

  defp refresh(live) do
    send(live.pid, :refresh)
  end

  defp expand_queue(live, queue) do
    live
    |> element("#queue-#{queue} button[rel=expand]")
    |> render_click()
  end

  defp change_sort(live, mode) do
    live
    |> element("#queues-table a[rel=sort]", mode)
    |> render_click()
  end

  defp time_iso_now do
    Time.utc_now()
    |> Time.truncate(:second)
    |> Time.to_iso8601()
  end
end
