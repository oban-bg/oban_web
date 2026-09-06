defmodule Oban.Web.Pages.Queues.IndexTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  setup do
    oban = start_supervised_oban!()

    {:ok, live, _html} = live(build_conn(), "/oban/queues")

    {:ok, live: live, oban: oban}
  end

  test "viewing active queues", %{live: live, oban: oban} do
    gossip(oban, node: "web.1", queue: "alpha")
    gossip(oban, node: "web.2", queue: "alpha")
    gossip(oban, node: "web.1", queue: "gamma")

    refresh(live)

    assert has_element?(live, "#queues-table li#queue-alpha")
    assert has_element?(live, "#queues-table li#queue-gamma")
  end

  test "viewing rate-limit indicator", %{live: live, oban: oban} do
    rate_limit = %{
      allowed: 10,
      period: 60,
      window_time: time_iso_now(),
      windows: [%{curr_count: 3, prev_count: 0}]
    }

    gossip(oban, node: "web.1", queue: "alpha", rate_limit: rate_limit)
    gossip(oban, node: "web.2", queue: "alpha", rate_limit: rate_limit)

    refresh(live)

    assert has_element?(live, "#queue-alpha #alpha-has-rate")
  end

  test "pausing and resuming selected queues", %{live: live, oban: oban} do
    :telemetry_test.attach_event_handlers(self(), [[:oban_web, :action, :stop]])

    gossip(oban, node: "web.1", queue: "alpha")
    gossip(oban, node: "web.2", queue: "bravo")

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

  test "stopping selected queues asks for confirmation", %{live: live, oban: oban} do
    gossip(oban, node: "web.1", queue: "alpha")
    gossip(oban, node: "web.2", queue: "bravo")

    refresh(live)

    live
    |> element("#queue-alpha button[rel=check]")
    |> render_click()

    assert has_element?(live, "#search")
    assert has_element?(live, "#selected-count", "1 selected")

    assert has_element?(
             live,
             "#bulk-actions #stop-queues[data-confirm*='Stop the alpha queue on every node?']"
           )

    live
    |> element("#queue-bravo button[rel=check]")
    |> render_click()

    assert has_element?(
             live,
             "#bulk-actions #stop-queues[data-confirm*='Stop the alpha, bravo queues on every node?']"
           )
  end

  test "queue checkboxes are named for screen readers", %{live: live, oban: oban} do
    gossip(oban, node: "web.1", queue: "alpha")

    refresh(live)

    assert has_element?(
             live,
             "#queue-alpha button[role=checkbox][aria-checked=false][aria-label='Select queue alpha']"
           )

    live
    |> element("#queue-alpha button[rel=check]")
    |> render_click()

    assert has_element?(live, "#queue-alpha button[role=checkbox][aria-checked=true]")
    assert has_element?(live, "#toggle-select[role=checkbox][aria-checked=true]")
  end

  test "selecting all queues matching the current filters", %{live: live, oban: oban} do
    gossip(oban, node: "web.1", queue: "alpha")
    gossip(oban, node: "web.2", queue: "bravo", paused: true)

    refresh(live)

    toggle_select_all(live)

    assert has_element?(live, "#queue-alpha")
    assert has_element?(live, "#queue-bravo")
    assert has_element?(live, "#selected-count", "2")

    toggle_select_all(live)

    {:ok, live, _html} = live(build_conn(), "/oban/queues?stats=paused")

    refute has_element?(live, "#queue-alpha")
    assert has_element?(live, "#queue-bravo")

    toggle_select_all(live)

    assert has_element?(live, "#selected-count", "1")
  end

  test "sorting queues by different properties", %{live: live, oban: oban} do
    rate_limit = %{
      allowed: 10,
      period: 60,
      window_time: time_iso_now(),
      windows: [%{curr_count: 3, prev_count: 0}]
    }

    gossip(oban, node: "web.1", queue: "alpha")
    gossip(oban, node: "web.1", queue: "gamma", rate_limit: rate_limit)

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
