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

    assert has_element?(live, "#queues-table li#queue-alpha")
    assert has_element?(live, "#queues-table li#queue-gamma")
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
  end

  test "pausing and resuming selected queues", %{live: live} do
    :telemetry_test.attach_event_handlers(self(), [[:oban_web, :action, :stop]])

    gossip(node: "web.1", queue: "alpha")
    gossip(node: "web.2", queue: "bravo")

    refresh(live)

    live
    |> element("#queue-alpha button[rel=check]")
    |> render_click()

    live
    |> element("#bulk-actions #pause-queues")
    |> render_click()

    assert_receive {_event, _ref, _timing, %{action: :pause_queues}}

    live
    |> element("#queue-alpha button[rel=check]")
    |> render_click()

    live
    |> element("#bulk-actions #resume-queues")
    |> render_click()

    assert_receive {_event, _ref, _timing, %{action: :resume_queues}}
  end

  test "selecting all queues matching the current filters", %{live: live} do
    gossip(node: "web.1", queue: "alpha")
    gossip(node: "web.2", queue: "bravo", paused: true)

    refresh(live)

    toggle_select_all(live)

    assert has_element?(live, "#queue-alpha")
    assert has_element?(live, "#queue-bravo")
    assert has_element?(live, "#selected-count", "2")

    toggle_select_all(live)

    live
    |> element("#sidebar #statuses-rows #filter-paused")
    |> render_click()

    refute has_element?(live, "#queue-alpha")
    assert has_element?(live, "#queue-bravo")

    toggle_select_all(live)

    assert has_element?(live, "#selected-count", "1")
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

    assert has_element?(live, "#queues-sort")

    for mode <- ~w(nodes exec avail local global rate_limit started) do
      change_sort(live, mode)

      assert_patch(live, queues_path(sort_by: mode, sort_dir: "asc"))
    end
  end

  defp queues_path(params) do
    "/oban/queues?#{URI.encode_query(params)}"
  end

  defp refresh(live) do
    send(live.pid, :refresh)
  end

  defp change_sort(live, mode) do
    live
    |> element("a#sort-#{mode}")
    |> render_click()
  end

  defp time_iso_now do
    Time.utc_now()
    |> Time.truncate(:second)
    |> Time.to_iso8601()
  end

  defp toggle_select_all(live) do
    live
    |> element("#toggle-select")
    |> render_click()
  end
end
