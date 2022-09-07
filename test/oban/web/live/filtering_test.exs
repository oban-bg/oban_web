defmodule Oban.Web.Live.FilteringTest do
  use Oban.Web.DataCase

  import Phoenix.LiveViewTest

  setup do
    start_supervised_oban!()

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live}
  end

  test "viewing jobs by state", %{live: live} do
    now = DateTime.utc_now()

    insert_job!([ref: 1], worker: AvailableWorker, state: "available")
    insert_job!([ref: 2], worker: ScheduledWorker, state: "scheduled")
    insert_job!([ref: 3], worker: RetryableWorker, state: "retryable")
    insert_job!([ref: 4], worker: CancelledWorker, state: "cancelled", cancelled_at: now)
    insert_job!([ref: 5], worker: DiscardedWorker, state: "discarded", discarded_at: now)
    insert_job!([ref: 6], worker: CompletedWorker, state: "completed", completed_at: now)

    for state <- ~w(available scheduled retryable cancelled discarded completed) do
      title = String.capitalize(state)

      click_state(live, state)
      assert has_job?(live, "#{title}Worker")
      assert has_element?(live, "#jobs-header", "(1/1 #{title})")
    end
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
    click_node(live, "web-2_oban")
    assert_patch(live, jobs_path(nodes: "web-2/oban", sort_dir: "asc", state: "available"))

    refute has_job?(live, "AlphaWorker")
    assert has_job?(live, "DeltaWorker")
    refute has_job?(live, "GammaWorker")

    click_node(live, "web-1_oban")

    assert_patch(
      live,
      jobs_path(nodes: "web-1/oban,web-2/oban", sort_dir: "asc", state: "available")
    )

    assert has_job?(live, "AlphaWorker")
    assert has_job?(live, "DeltaWorker")
    assert has_job?(live, "GammaWorker")
  end

  test "viewing available or scheduled clears the node filter", %{live: live} do
    gossip(node: "web-1", queue: "alpha")

    click_state(live, "executing")
    click_node(live, "web-1_oban")
    assert_patch(live, jobs_path(nodes: "web-1/oban"))

    click_state(live, "available")
    assert_patch(live, jobs_path(sort_dir: "asc", state: "available"))
  end

  test "filtering jobs by queue", %{live: live} do
    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker)
    insert_job!([ref: 2], queue: "delta", worker: DeltaWorker)
    insert_job!([ref: 3], queue: "gamma", worker: GammaWorker)

    click_state(live, "available")
    click_queue(live, "delta")

    refute has_job?(live, "AlphaWorker")
    assert has_job?(live, "DeltaWorker")
    refute has_job?(live, "GammaWorker")

    click_queue(live, "alpha")
    assert_patch(live, jobs_path(queues: "alpha,delta", sort_dir: "asc", state: "available"))

    assert has_job?(live, "AlphaWorker")
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
    |> element("#jobs-table button[rel='worker-AlphaWorker']")
    |> render_click()

    assert has_job?(live, "AlphaWorker")
    refute has_job?(live, "DeltaWorker")
    refute has_job?(live, "GammaWorker")
  end

  defp jobs_path(params) do
    "/oban/jobs?#{URI.encode_query(params)}"
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
    has_element?(live, "#jobs-table", worker_name)
  end

  defp refresh(live) do
    send(live.pid, :refresh)
  end
end
