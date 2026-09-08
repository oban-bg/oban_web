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

  test "pending counts and status icons are named for screen readers", %{live: live, oban: oban} do
    gossip(oban, node: "web.1", queue: "alpha", paused: true)

    refresh(live)

    assert has_element?(live, "#queue-alpha #alpha-available .sr-only", "available")
    assert has_element?(live, "#queue-alpha #alpha-scheduled .sr-only", "scheduled")
    assert has_element?(live, "#queue-alpha #alpha-retryable .sr-only", "retryable")
    assert has_element?(live, "#queue-alpha [rel=nodes] .sr-only", "nodes")
    assert has_element?(live, "#queue-alpha #alpha-util .sr-only", "0 of 1 executing")

    assert has_element?(
             live,
             "#sparkline-alpha[aria-label='Recent activity, peak 0 of 1 executing']"
           )

    assert has_element?(live, "#queue-alpha #alpha-is-paused .sr-only", "All paused")
  end

  test "counting jobs by state with links into the jobs list", %{live: live, oban: oban} do
    gossip(oban, node: "web.1", queue: "alpha")
    gossip(oban, node: "web.1", queue: "bravo")

    record(oban, :full_count, 4, %{"queue" => "alpha", "state" => "available"})
    record(oban, :full_count, 6, %{"queue" => "alpha", "state" => "scheduled"})
    record(oban, :full_count, 3512, %{"queue" => "alpha", "state" => "retryable"})
    record(oban, :full_count, 2, %{"queue" => "bravo", "state" => "scheduled"})

    refresh(live)

    assert has_element?(
             live,
             "#alpha-available[href*='queues=alpha'][href*='state=available']",
             "4"
           )

    assert has_element?(live, "#alpha-scheduled[href*='state=scheduled']", "6")
    assert has_element?(live, "#alpha-retryable[href*='state=retryable']", "3.5k")
    assert has_element?(live, "#alpha-retryable[data-title='3,512 retryable']")
    assert has_element?(live, "#bravo-scheduled", "2")
    assert has_element?(live, "#bravo-retryable", "0")
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
    assert has_element?(live, "#notice", "Paused the alpha queue on every node")

    live
    |> element("#queue-alpha button[rel=check]")
    |> render_click()

    live
    |> element("#queue-bravo button[rel=check]")
    |> render_click()

    live
    |> element("#bulk-actions #resume-queues")
    |> render_click()

    assert_receive {_event, _ref, _timing, %{action: :resume_queues}}
    assert has_element?(live, "#notice", "Resumed the alpha, bravo queues on every node")
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
    assert has_element?(live, "#toggle-select[aria-checked=true]")

    # The header reflects the filtered list, so it can clear what it selected.
    toggle_select_all(live)

    refute has_element?(live, "#selected-count")
  end

  test "filtering queues by name with a bare search term", %{live: live, oban: oban} do
    gossip(oban, node: "web.1", queue: "alpha")
    gossip(oban, node: "web.1", queue: "bravo")

    refresh(live)

    live
    |> form("#search")
    |> tap(&render_change(&1, %{terms: "alp"}))
    |> tap(&render_submit(&1, %{}))

    assert_patch(live, queues_path(names: "alp"))
    assert has_element?(live, "#search #search-filter-names", "names:alp")
    assert has_element?(live, "#queue-alpha")
    refute has_element?(live, "#queue-bravo")
  end

  test "sorting queues by different properties", %{live: live, oban: oban} do
    rate_limit = %{
      allowed: 10,
      period: 60,
      window_time: time_iso_now(),
      windows: [%{curr_count: 3, prev_count: 0}]
    }

    gossip(oban, node: "web.1", queue: "alpha", running: [1, 2])
    gossip(oban, node: "web.1", queue: "gamma", rate_limit: rate_limit)

    record(oban, :full_count, 5, %{"queue" => "alpha", "state" => "available"})
    record(oban, :full_count, 2, %{"queue" => "gamma", "state" => "retryable"})

    refresh(live)

    assert has_element?(live, "#queues-sort")

    for mode <- ~w(nodes avail sched retry exec local global rate_limit started) do
      change_sort(live, mode)

      assert_patch(live, queues_path(sort_by: mode, sort_dir: "asc"))
    end

    # Ascending puts the idle queue first, which only holds when the counts are actually read.
    change_sort(live, "avail")
    assert ~w(gamma alpha) == queue_order(live)

    change_sort(live, "exec")
    assert ~w(gamma alpha) == queue_order(live)

    change_sort(live, "retry")
    assert ~w(alpha gamma) == queue_order(live)

    change_sort(live, "name")
    assert ~w(alpha gamma) == queue_order(live)
  end

  defp queues_path(params) do
    "/oban/queues?#{URI.encode_query(params)}"
  end

  defp queue_order(live) do
    ~r/id="queue-([\w-]+)"/
    |> Regex.scan(render(live))
    |> Enum.map(fn [_match, name] -> name end)
  end

  defp record(oban, series, value, labels) do
    labels = Map.put_new(labels, "node", "web.1")

    oban
    |> Oban.Registry.via(Oban.Met.Recorder)
    |> Oban.Met.Recorder.store(series, Oban.Met.Values.Gauge.new(value), labels)
  end

  defp refresh(live) do
    send(live.pid, :refresh)
  end

  defp change_sort(live, mode) do
    live
    |> element("#sort-#{mode}")
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
