defmodule Oban.Web.Pages.Jobs.IndexTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  setup do
    oban = start_supervised_oban!()

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live, oban: oban}
  end

  describe "filtering" do
    test "viewing jobs by state", %{live: live, oban: oban} do
      now = DateTime.utc_now()

      changesets = [
        Job.new(%{ref: 1}, worker: AvailableWorker, state: "available"),
        Job.new(%{ref: 2}, worker: ScheduledWorker, state: "scheduled"),
        Job.new(%{ref: 3}, worker: RetryableWorker, state: "retryable"),
        Job.new(%{ref: 4}, worker: CancelledWorker, state: "cancelled", cancelled_at: now),
        Job.new(%{ref: 5}, worker: DiscardedWorker, state: "discarded", discarded_at: now),
        Job.new(%{ref: 6}, worker: CompletedWorker, state: "completed", completed_at: now)
      ]

      Oban.insert_all(oban, changesets)

      flush_reporter(oban)

      for state <- ~w(available scheduled retryable cancelled discarded completed) do
        title = String.capitalize(state)

        click_state(live, state)

        assert has_job?(live, "#{title}Worker")
      end
    end

    test "naming the deep linked state before the socket connects" do
      html =
        build_conn()
        |> get("/oban/jobs?state=discarded")
        |> html_response(200)

      doc = LazyHTML.from_document(html)

      assert ["filter-discarded"] =
               doc
               |> LazyHTML.query("#sidebar #states [aria-current=true]")
               |> LazyHTML.attribute("id")

      assert doc |> LazyHTML.query("#jobs-header #jobs-state") |> LazyHTML.text() =~ "discarded"
    end

    test "naming the state on the panel and in the time column", %{live: live} do
      assert has_element?(live, "#jobs-header #jobs-state", "executing")
      assert has_element?(live, "#jobs-table", "running")

      render_patch(live, "/oban/jobs?state=retryable")

      assert has_element?(live, "#jobs-header #jobs-state", "retryable")
      assert has_element?(live, "#jobs-table", "next retry")
    end

    test "filtering jobs by node", %{live: live, oban: oban} do
      web_1 = ["web-1", "aaaa-aaaa"]
      web_2 = ["web-2", "bbbb-bbbb"]

      gossip(oban, node: "web-1", queue: "alpha")
      gossip(oban, node: "web-2", queue: "alpha")

      insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker, attempted_by: web_1)
      insert_job!([ref: 2], queue: "alpha", worker: DeltaWorker, attempted_by: web_2)
      insert_job!([ref: 3], queue: "alpha", worker: GammaWorker, attempted_by: web_1)

      click_state(live, "available")
      click_node(live, "web-2")
      assert_patch(live, jobs_path(nodes: "web-2", state: "available"))

      refute has_job?(live, "AlphaWorker")
      assert has_job?(live, "DeltaWorker")
      refute has_job?(live, "GammaWorker")

      click_node(live, "web-1")

      assert_patch(live, jobs_path(nodes: "web-1,web-2", state: "available"))

      assert has_job?(live, "AlphaWorker")
      assert has_job?(live, "DeltaWorker")
      assert has_job?(live, "GammaWorker")
    end

    test "indicating rescued jobs", %{live: live} do
      job_1 =
        insert_job!([ref: 1],
          state: "executing",
          worker: AlphaWorker,
          attempted_at: DateTime.utc_now(),
          attempted_by: ["web-1", "aaaa-aaaa"],
          meta: %{"rescued" => 1}
        )

      job_2 =
        insert_job!([ref: 2],
          state: "executing",
          worker: GammaWorker,
          attempted_at: DateTime.utc_now(),
          attempted_by: ["web-1", "aaaa-aaaa"]
        )

      click_state(live, "executing")

      assert has_job?(live, "AlphaWorker")

      assert has_element?(live, "#job-rescued-#{job_1.id} .sr-only", "Rescued by lifeline")
      refute has_element?(live, "#job-rescued-#{job_2.id}")
    end

    test "indicating orphaned jobs", %{live: live, oban: oban} do
      now = DateTime.utc_now()

      web_1 = ["web-1", "aaaa-aaaa"]
      web_2 = ["web-1", "bbbb-bbbb"]

      gossip(oban, node: "web-1", queue: "alpha", uuid: "bbbb-bbbb")

      job_1 =
        insert_job!([ref: 1],
          state: "executing",
          worker: AlphaWorker,
          attempted_at: now,
          attempted_by: web_1
        )

      job_2 =
        insert_job!([ref: 2],
          state: "executing",
          worker: GammaWorker,
          attempted_at: now,
          attempted_by: web_2
        )

      click_state(live, "executing")

      assert has_job?(live, "AlphaWorker")
      assert has_job?(live, "GammaWorker")

      assert has_element?(live, "#job-orphaned-#{job_1.id} .sr-only", "Orphaned")
      refute has_element?(live, "#job-orphaned-#{job_2.id}")
    end

    test "viewing available or scheduled clears the node filter", %{live: live, oban: oban} do
      gossip(oban, node: "web-1", queue: "alpha")

      click_state(live, "executing")
      click_node(live, "web-1")
      assert_patch(live, jobs_path(nodes: "web-1"))

      click_state(live, "available")
      assert_patch(live, jobs_path(nodes: "web-1", state: "available"))
    end

    test "filtering jobs by queue", %{live: live, oban: oban} do
      gossip(oban, node: "web-1", queue: "alpha")
      gossip(oban, node: "web-1", queue: "delta")
      gossip(oban, node: "web-1", queue: "gamma")

      changesets = [
        Job.new(%{ref: 1}, queue: "alpha", worker: AlphaWorker),
        Job.new(%{ref: 2}, queue: "delta", worker: DeltaWorker),
        Job.new(%{ref: 3}, queue: "gamma", worker: GammaWorker)
      ]

      Oban.insert_all(oban, changesets)

      flush_reporter(oban)

      click_state(live, "available")
      click_queue(live, "delta")

      refute has_job?(live, "AlphaWorker")
      assert has_job?(live, "DeltaWorker")
      refute has_job?(live, "GammaWorker")

      click_queue(live, "alpha")
      assert_patch(live, jobs_path(state: "available", queues: "alpha,delta"))

      assert has_job?(live, "AlphaWorker")
      assert has_job?(live, "DeltaWorker")
      refute has_job?(live, "GammaWorker")
    end

    test "the third queue column follows the selected state", %{live: live, oban: oban} do
      gossip(oban, node: "web-1", queue: "alpha")
      gossip(oban, node: "web-1", queue: "delta")

      now = DateTime.utc_now()

      changesets = [
        Job.new(%{ref: 1}, queue: "alpha", worker: AlphaWorker),
        Job.new(%{ref: 2},
          queue: "alpha",
          worker: AlphaWorker,
          state: "discarded",
          discarded_at: now
        ),
        Job.new(%{ref: 3},
          queue: "alpha",
          worker: AlphaWorker,
          state: "discarded",
          discarded_at: now
        ),
        Job.new(%{ref: 4},
          queue: "delta",
          worker: DeltaWorker,
          state: "discarded",
          discarded_at: now
        )
      ]

      Oban.insert_all(oban, changesets)

      flush_reporter(oban)
      refresh(live)

      assert has_element?(live, "#queues-header-2[data-title=available] .sr-only", "available")
      assert has_element?(live, "#sidebar #queues #filter-alpha .sr-only", "available")

      click_state(live, "discarded")

      assert has_element?(live, "#queues-header-2[data-title=discarded] .sr-only", "discarded")
      assert has_element?(live, "#sidebar #queues #filter-alpha", ~r/discarded\s+2/)
      assert has_element?(live, "#sidebar #queues #filter-delta", ~r/discarded\s+1/)
    end

    test "queues without limits or pauses hide the mode column", %{live: live, oban: oban} do
      gossip(oban, node: "web-1", queue: "alpha")

      refute has_element?(live, "#queues-header-mode")

      gossip(oban, node: "web-1", queue: "delta", paused: true)
      refresh(live)

      assert has_element?(live, "#queues-header-mode[data-title]")
      assert has_element?(live, "#mode-delta-paused.text-amber-500 .sr-only", "All paused")
    end

    test "filtering through the autocomplete toolbar", %{live: live, oban: oban} do
      gossip(oban, node: "web-1", queue: "alpha")
      gossip(oban, node: "web-1", queue: "delta")
      gossip(oban, node: "web-1", queue: "gamma")

      changesets = [
        Job.new(%{ref: 1}, queue: "alpha", worker: AlphaWorker),
        Job.new(%{ref: 2}, queue: "delta", worker: DeltaWorker),
        Job.new(%{ref: 3}, queue: "gamma", worker: GammaWorker)
      ]

      Oban.insert_all(oban, changesets)

      flush_reporter(oban)

      click_state(live, "available")

      live
      |> form("#search")
      |> tap(&render_change(&1, %{terms: "queues:alpha,delta"}))
      |> tap(&render_submit(&1, %{}))

      assert_patch(live, jobs_path(state: "available", queues: "alpha,delta"))

      assert has_job?(live, "AlphaWorker")
      assert has_job?(live, "DeltaWorker")
      refute has_job?(live, "GammaWorker")
    end
  end

  describe "sorting" do
    test "sorting jobs by different properties", %{live: live} do
      insert_job!([ref: 1], worker: Worker.A, state: "available", queue: "gamma")
      insert_job!([ref: 2], worker: Worker.B, state: "available", queue: "delta")
      insert_job!([ref: 3], worker: Worker.C, state: "available", queue: "alpha")

      click_state(live, "available")

      for mode <- ~w(worker queue time) do
        change_sort(live, mode)

        assert_patch(
          live,
          jobs_path(sort_by: mode, sort_dir: "asc", state: "available")
        )
      end
    end

    test "flipping the sort direction", %{live: live} do
      live
      |> element("#job-sort-dir[aria-label=\"Sorted ascending, switch to descending\"]")
      |> render_click()

      assert_patch(live, jobs_path(sort_by: "time", sort_dir: "desc"))

      assert has_element?(
               live,
               "#job-sort-dir[aria-label=\"Sorted descending, switch to ascending\"]"
             )
    end
  end

  describe "bulk operations" do
    test "cancelling selected jobs", %{live: live, oban: oban} do
      [job_1, _job, job_3] =
        Oban.insert_all(oban, [
          Job.new(%{ref: 1}, state: "available", worker: WorkerA),
          Job.new(%{ref: 2}, state: "available", worker: WorkerB),
          Job.new(%{ref: 3}, state: "available", worker: WorkerC)
        ])

      click_state(live, "available")
      select_jobs(live, [job_1, job_3])
      click_bulk_action(live, "cancel-jobs")

      hidden_job?(live, job_1)
      hidden_job?(live, job_3)
    end

    test "deleting selected jobs", %{live: live, oban: oban} do
      [job_1, _job, job_3] =
        Oban.insert_all(oban, [
          Job.new(%{ref: 1}, state: "available", worker: WorkerA),
          Job.new(%{ref: 2}, state: "available", worker: WorkerB),
          Job.new(%{ref: 3}, state: "available", worker: WorkerC)
        ])

      click_state(live, "available")
      select_jobs(live, [job_1, job_3])
      click_bulk_action(live, "delete-jobs")

      hidden_job?(live, job_1)
      hidden_job?(live, job_3)
    end
  end

  describe "bulk safety" do
    test "bulk actions ask for confirmation naming the selection", %{oban: oban} do
      [job_1, job_2] =
        Oban.insert_all(oban, [
          Job.new(%{ref: 1}, state: "available", queue: "alpha", worker: WorkerA),
          Job.new(%{ref: 2}, state: "available", queue: "alpha", worker: WorkerB)
        ])

      {:ok, live, _html} = live(build_conn(), jobs_path(state: "available", queues: "alpha"))

      select_jobs(live, [job_1])

      assert has_element?(
               live,
               "#bulk-actions #delete-jobs[data-confirm*='Delete 1 available job matching queues:alpha?']"
             )

      select_jobs(live, [job_2])

      assert has_element?(
               live,
               "#bulk-actions #cancel-jobs[data-confirm*='Cancel 2 available jobs matching queues:alpha?']"
             )

      assert has_element?(live, "#selected-count", "2 selected")
      refute has_element?(live, "#selected-limit")
      assert has_element?(live, "#search #search-filter-queues", "queues:alpha")
    end

    test "selection survives loading more but not changing filters", %{live: live, oban: oban} do
      changesets = Enum.map(1..21, &Job.new(%{ref: &1}, state: "available", worker: WorkerA))

      [job | _rest] = Oban.insert_all(oban, changesets)

      click_state(live, "available")
      select_jobs(live, [job])

      live
      |> element("#jobs-table button", "Show More")
      |> render_click()

      assert has_element?(live, "#selected-count", "1 selected")

      click_state(live, "scheduled")

      refute has_element?(live, "#bulk-actions")
    end

    test "the header checkbox completes a partial selection before clearing it", %{
      live: live,
      oban: oban
    } do
      [job_1, job_2] =
        Oban.insert_all(oban, [
          Job.new(%{ref: 1}, state: "available", worker: WorkerA),
          Job.new(%{ref: 2}, state: "available", worker: WorkerB)
        ])

      click_state(live, "available")

      assert has_element?(live, "#toggle-select[aria-label='Select all']")

      select_jobs(live, [job_1])

      assert has_element?(
               live,
               "#toggle-select[aria-checked=mixed][aria-label='Select the rest']"
             )

      toggle_select_all(live)

      assert has_element?(live, "#job-#{job_2.id} button[role=checkbox][aria-checked=true]")
      assert has_element?(live, "#selected-count", "2 selected")
      assert has_element?(live, "#toggle-select[aria-checked=true][aria-label='Clear selection']")

      toggle_select_all(live)

      refute has_element?(live, "#selected-count")
    end

    test "select all reports when the bulk action limit is reached", %{oban: oban} do
      Oban.insert_all(oban, [
        Job.new(%{ref: 1}, state: "available", worker: WorkerA),
        Job.new(%{ref: 2}, state: "available", worker: WorkerB),
        Job.new(%{ref: 3}, state: "available", worker: WorkerC)
      ])

      {:ok, live, _html} = live(build_conn(), "/oban-capped/jobs?state=available")

      live
      |> element("#toggle-select")
      |> render_click()

      assert has_element?(live, "#selected-count", "3 selected")
      assert has_element?(live, "#selected-limit", "limit reached")
      assert has_element?(live, "#selected-limit[data-title*='stops at 2 jobs']")
    end
  end

  describe "chart" do
    test "explaining an empty window instead of drawing nothing", %{live: live} do
      assert has_element?(live, "#chart-empty", "No executions recorded in the last 1m 40s")
    end

    test "switching series with a radio group and keeping percentiles for time series", %{
      live: live
    } do
      assert has_element?(live, "#chart-series[role=radiogroup]")
      assert has_element?(live, "#select-series-exec_count[role=radio][aria-checked=true]")
      refute has_element?(live, "#chart-options-menu #select-ntile-p95")

      live
      |> element("#select-series-exec_time")
      |> render_click()

      assert has_element?(live, "#select-series-exec_time[aria-checked=true]")
      assert has_element?(live, "#select-series-exec_count[aria-checked=false]")
      assert has_element?(live, "#chart-options-menu #select-ntile-p95[aria-checked=true]")
      assert has_element?(live, "#chart-h", "p95 · 1s by State")
    end

    test "grouping by a filter only when it carries more than one value", %{live: live} do
      assert has_element?(live, "#chart-h", "1s by State")

      render_patch(live, jobs_path(queues: "alpha"))

      assert has_element?(live, "#chart-h", "1s by State")

      render_patch(live, jobs_path(queues: "alpha,delta"))

      assert has_element?(live, "#chart-h", "1s by Queue")

      render_patch(live, jobs_path(nodes: "web-1,web-2", queues: "alpha,delta"))

      assert has_element?(live, "#chart-h", "1s by Node")

      live
      |> element("#select-series-full_count")
      |> render_click()

      assert has_element?(live, "#chart-h", "1s by Queue")
    end

    test "naming the state that narrows a non-state grouping", %{live: live} do
      render_patch(live, jobs_path(queues: "alpha,delta", state: "discarded"))

      assert has_element?(live, "#chart-h", "1s by Queue, discarded")
    end

    test "isolating the selected state at the baseline", %{live: live, oban: oban} do
      record(oban, "exec_count", 3, %{"state" => "completed"})
      record(oban, "exec_count", 1, %{"state" => "discarded"})

      render_patch(live, jobs_path(state: "discarded"))

      assert_push_event(live, "chart-change", %{
        points: [%{label: "discarded", ghost: false}, %{label: "completed", ghost: true}]
      })

      assert has_element?(live, ~s(#chart[aria-label$="discarded isolated"]))

      # A state without a series leaves the stack alone rather than graying everything out.
      render_patch(live, jobs_path(state: "available"))

      assert_push_event(live, "chart-change", %{
        points: [%{label: "discarded", ghost: false}, %{label: "completed", ghost: false}]
      })

      refute has_element?(live, ~s(#chart[aria-label$="isolated"]))
    end

    test "pushing fresh points on every refresh", %{live: live} do
      assert_push_event(live, "chart-change", %{now: first})

      send(live.pid, :refresh)

      assert_push_event(live, "chart-change", %{now: second})
      assert second >= first
    end

    test "drilling into a state series filters the table by that state", %{live: live} do
      live
      |> element("#chart-canvas")
      |> render_hook("chart-select", %{"label" => "completed"})

      assert_patch(live, jobs_path(state: "completed"))
    end

    test "drilling into a queue series narrows to that queue", %{live: live} do
      render_patch(live, jobs_path(queues: "alpha,delta"))

      live
      |> element("#chart-canvas")
      |> render_hook("chart-select", %{"label" => "alpha"})

      assert_patch(live, jobs_path(queues: "alpha"))
    end

    test "ignoring drill-through on the folded other series", %{live: live} do
      render_patch(live, jobs_path(queues: "alpha,delta"))
      assert_patch(live, jobs_path(queues: "alpha,delta"))

      live
      |> element("#chart-canvas")
      |> render_hook("chart-select", %{"label" => "other"})

      refute_receive {_ref, {:patch, _topic, _opts}}, 50
    end

    test "keeping chart selections after leaving and returning", %{live: live} do
      job = insert_job!([ref: 1])

      live
      |> element("#select-series-exec_time")
      |> render_click()

      live
      |> element("#select-period-1m")
      |> render_click()

      assert has_element?(live, "#chart-h h3", "Execution Time")

      render_patch(live, "/oban/jobs/#{job.id}")

      refute has_element?(live, "#chart")

      render_patch(live, "/oban/jobs")

      assert has_element?(live, "#chart-h h3", "Execution Time")
      assert has_element?(live, "#chart-h", "p95 · 1m by State")

      render_patch(live, "/oban/queues")

      refute has_element?(live, "#chart")

      render_patch(live, "/oban/jobs")

      assert has_element?(live, "#chart-h h3", "Execution Time")
    end

    test "naming the chart for assistive technology", %{live: live} do
      assert has_element?(
               live,
               ~s(#chart-toggle[aria-expanded="true"][aria-controls="chart-body"])
             )

      assert has_element?(live, ~s(#chart[role="img"]))
    end
  end

  describe "keyboard and screen reader access" do
    test "search input is a combobox with named suggestions and controls", %{live: live} do
      assert has_element?(
               live,
               "#search-input[role=combobox][aria-controls=search-options][aria-expanded=false]"
             )

      assert has_element?(live, "#search-options[role=listbox] #search-option-0[role=option]")
      assert has_element?(live, "#search-keys", "Tab")

      live
      |> form("#search")
      |> tap(&render_change(&1, %{terms: "queues:alpha"}))
      |> tap(&render_submit(&1, %{}))

      assert has_element?(live, "#search-reset[aria-label='Clear filters']")

      assert has_element?(
               live,
               "#search-filter-queues button[aria-label='Remove filter queues:alpha']"
             )
    end

    test "sidebar filters are a labelled landmark with pressed and current states", %{
      live: live,
      oban: oban
    } do
      gossip(oban, node: "web-1", queue: "alpha")
      refresh(live)

      assert has_element?(live, "aside#sidebar[aria-label='Job filters']")
      assert has_element?(live, "#sidebar #states a#filter-executing[aria-current=true]")
      assert has_element?(live, "#sidebar #queues button#filter-alpha[aria-pressed=false]")
      assert has_element?(live, "#sidebar #nodes button#filter-web-1 .sr-only", "executing")
      assert has_element?(live, "#sidebar [role=separator][aria-valuetext='320 pixels']")

      click_queue(live, "alpha")

      assert has_element?(live, "#sidebar #queues button#filter-alpha[aria-pressed=true]")
    end

    test "collapsing a section is announced and remembered", %{live: live} do
      assert has_element?(live, "#nodes-toggle[aria-expanded=true][aria-label='Collapse nodes']")

      live
      |> element("#nodes-toggle")
      |> render_click()

      assert_push_event(live, "update-sidebar-collapsed", %{names: ["nodes"]})
      assert has_element?(live, "#nodes-toggle[aria-expanded=false][aria-label='Expand nodes']")
      assert has_element?(live, "#nodes-rows.hidden")

      live
      |> element("#nodes-toggle")
      |> render_click()

      assert_push_event(live, "update-sidebar-collapsed", %{names: []})
      refute has_element?(live, "#nodes-rows.hidden")
    end

    test "empty sections say why they are empty", %{live: live} do
      assert has_element?(live, "#nodes-rows", "No nodes reporting")
      assert has_element?(live, "#queues-rows", "No queues running")
    end

    test "row and select all checkboxes announce their state", %{live: live, oban: oban} do
      [job_1, job_2] =
        Oban.insert_all(oban, [
          Job.new(%{ref: 1}, state: "available", worker: WorkerA),
          Job.new(%{ref: 2}, state: "available", worker: WorkerB)
        ])

      click_state(live, "available")

      assert has_element?(live, "#toggle-select[role=checkbox][aria-checked=false]")

      assert has_element?(
               live,
               "#job-#{job_1.id} button[role=checkbox][aria-checked=false][aria-label='Select job #{job_1.id}']"
             )

      select_jobs(live, [job_1])

      assert has_element?(live, "#job-#{job_1.id} button[role=checkbox][aria-checked=true]")
      assert has_element?(live, "#job-#{job_2.id} button[role=checkbox][aria-checked=false]")
      assert has_element?(live, "#toggle-select[aria-checked=mixed]")

      select_jobs(live, [job_2])

      assert has_element?(live, "#toggle-select[aria-checked=true]")
    end
  end

  defp click_node(live, node) do
    live
    |> element("#sidebar #nodes #filter-#{node}")
    |> render_click()

    refresh(live)
  end

  defp click_queue(live, queue) do
    live
    |> element("#sidebar #filter-#{queue}")
    |> render_click()

    refresh(live)
  end

  defp change_sort(live, mode) do
    live
    |> element("#job-sort #sort-#{mode}")
    |> render_click()
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #filter-#{state}")
    |> render_click()
  end

  defp click_bulk_action(live, action) do
    live
    |> element("#bulk-actions ##{action}")
    |> render_click()
  end

  defp has_job?(live, worker_name) do
    has_element?(live, "#jobs-table", worker_name)
  end

  defp hidden_job?(live, %{id: id}) do
    refute has_element?(live, "#job-#{id}")
  end

  defp record(oban, series, value, labels) do
    labels = Map.merge(%{"node" => "web-1", "queue" => "alpha", "worker" => "Worker"}, labels)

    oban
    |> Oban.Registry.via(Oban.Met.Recorder)
    |> Oban.Met.Recorder.store(series, Oban.Met.Values.Gauge.new(value), labels)
  end

  defp jobs_path(params) do
    query =
      params
      |> Enum.sort()
      |> URI.encode_query()

    "/oban/jobs?#{query}"
  end

  defp refresh(live) do
    send(live.pid, :refresh)
  end

  defp toggle_select_all(live) do
    live
    |> element("#toggle-select")
    |> render_click()
  end

  defp select_jobs(live, jobs) do
    for %{id: id} <- jobs do
      live
      |> element("#jobs-table #job-#{id} button[rel=check]")
      |> render_click()
    end
  end
end
