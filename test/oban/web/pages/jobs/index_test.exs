defmodule Oban.Web.Pages.Jobs.IndexTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  setup do
    start_supervised_oban!()

    Job.states()

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live}
  end

  describe "filtering" do
    test "viewing jobs by state", %{live: live} do
      now = DateTime.utc_now()

      changesets = [
        Job.new(%{ref: 1}, worker: AvailableWorker, state: "available"),
        Job.new(%{ref: 2}, worker: ScheduledWorker, state: "scheduled"),
        Job.new(%{ref: 3}, worker: RetryableWorker, state: "retryable"),
        Job.new(%{ref: 4}, worker: CancelledWorker, state: "cancelled", cancelled_at: now),
        Job.new(%{ref: 5}, worker: DiscardedWorker, state: "discarded", discarded_at: now),
        Job.new(%{ref: 6}, worker: CompletedWorker, state: "completed", completed_at: now)
      ]

      Oban.insert_all(changesets)

      flush_reporter()

      for state <- ~w(available scheduled retryable cancelled discarded completed) do
        title = String.capitalize(state)

        click_state(live, state)

        assert has_job?(live, "#{title}Worker")
      end
    end

    test "filtering jobs by node", %{live: live} do
      web_1 = ["web-1", "aaaa-aaaa"]
      web_2 = ["web-2", "bbbb-bbbb"]

      gossip(node: "web-1", queue: "alpha")
      gossip(node: "web-2", queue: "alpha")

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

      assert has_element?(live, "#job-rescued-#{job_1.id}")
      refute has_element?(live, "#job-rescued-#{job_2.id}")
    end

    test "indicating orphaned jobs", %{live: live} do
      now = DateTime.utc_now()

      web_1 = ["web-1", "aaaa-aaaa"]
      web_2 = ["web-1", "bbbb-bbbb"]

      gossip(node: "web-1", queue: "alpha", uuid: "bbbb-bbbb")

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

      assert has_element?(live, "#job-orphaned-#{job_1.id}")
      refute has_element?(live, "#job-orphaned-#{job_2.id}")
    end

    test "viewing available or scheduled clears the node filter", %{live: live} do
      gossip(node: "web-1", queue: "alpha")

      click_state(live, "executing")
      click_node(live, "web-1")
      assert_patch(live, jobs_path(nodes: "web-1"))

      click_state(live, "available")
      assert_patch(live, jobs_path(nodes: "web-1", state: "available"))
    end

    test "filtering jobs by queue", %{live: live} do
      gossip(node: "web-1", queue: "alpha")
      gossip(node: "web-1", queue: "delta")
      gossip(node: "web-1", queue: "gamma")

      changesets = [
        Job.new(%{ref: 1}, queue: "alpha", worker: AlphaWorker),
        Job.new(%{ref: 2}, queue: "delta", worker: DeltaWorker),
        Job.new(%{ref: 3}, queue: "gamma", worker: GammaWorker)
      ]

      Oban.insert_all(changesets)

      flush_reporter()

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

    test "filtering through the autocomplete toolbar", %{live: live} do
      gossip(node: "web-1", queue: "alpha")
      gossip(node: "web-1", queue: "delta")
      gossip(node: "web-1", queue: "gamma")

      changesets = [
        Job.new(%{ref: 1}, queue: "alpha", worker: AlphaWorker),
        Job.new(%{ref: 2}, queue: "delta", worker: DeltaWorker),
        Job.new(%{ref: 3}, queue: "gamma", worker: GammaWorker)
      ]

      Oban.insert_all(changesets)

      flush_reporter()

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
          jobs_path(limit: 20, sort_by: mode, sort_dir: "asc", state: "available")
        )
      end
    end
  end

  describe "bulk operations" do
    test "cancelling selected jobs", %{live: live} do
      [job_1, _job, job_3] =
        Oban.insert_all([
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

    test "deleting selected jobs", %{live: live} do
      [job_1, _job, job_3] =
        Oban.insert_all([
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

  defp select_jobs(live, jobs) do
    for %{id: id} <- jobs do
      live
      |> element("#jobs-table #job-#{id} button[rel=check]")
      |> render_click()
    end
  end

  describe "enqueue job button" do
    test "shows enqueue button in sidebar", %{live: live} do
      assert has_element?(live, "#sidebar a", "Enqueue Job")
    end

    test "navigates to new job page when clicked", %{live: live} do
      live
      |> element("#sidebar a", "Enqueue Job")
      |> render_click()

      assert_patch(live, "/oban/jobs/new")
    end
  end
end
