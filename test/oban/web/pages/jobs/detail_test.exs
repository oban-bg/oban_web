defmodule Oban.Web.Pages.Jobs.DetailTest do
  use Oban.Web.Case, async: true

  setup :start_supervised_oban!

  test "viewing job details" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    live = open_job(job)

    assert page_title(live) =~ "WorkerA (#{job.id})"
  end

  test "naming controls and section state for assistive tech" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    live = open_job(job)

    assert has_element?(live, "h2 #back-link")

    assert has_element?(
             live,
             "#job-data-toggle[aria-expanded=true][aria-controls=job-data-content]"
           )

    assert has_element?(live, "#errors-toggle[aria-expanded=false][aria-controls=errors-content]")
    assert has_element?(live, "#edit-toggle[aria-expanded=true][aria-controls=edit-content]")
    assert has_element?(live, "#copy-args[aria-label]")
    assert has_element?(live, "#job-history-chart[role=img][aria-label]")
  end

  test "viewing details for a job that was deleted falls back" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    {:ok, live, _html} = live(build_conn(), "/oban")

    open_state(live, "available")

    Repo.delete!(job)

    open_details(live, job)

    refute has_element?(live, "#job-details")
  end

  test "cancelling a job from the detail view" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    live = open_job(job)

    assert has_element?(live, "#job-details")

    click_cancel(live)

    with_backoff(fn ->
      assert %{state: "cancelled"} = Repo.reload!(job)
    end)
  end

  test "immediately running a job from the detail view" do
    job = insert_job!([ref: 1], state: "scheduled", worker: WorkerA)

    live = open_job(job)

    assert has_element?(live, "#job-details")

    click_run_now(live)

    with_backoff(fn ->
      assert %{state: "available"} = Repo.reload!(job)
    end)
  end

  test "omitting chunk rows for ordinary jobs" do
    job = insert_job!([ref: 1], state: "completed", worker: WorkerA, attempted_by: ~w(web-1 a))

    live = open_job(job)

    refute has_element?(live, "#chunk-members")
    refute has_element?(live, "#chunk-leader-link")
  end

  test "omitting compensation links for ordinary jobs" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    live = open_job(job)

    refute has_element?(live, "#origin-job-link")
    refute has_element?(live, "#compensating-job-link")
  end

  defp open_job(job) do
    {:ok, live, _html} = live(build_conn(), "/oban/jobs/#{job.id}")

    live
  end

  defp open_state(live, state) do
    live
    |> element("#sidebar #states #filter-#{state}")
    |> render_click()
  end

  defp open_details(live, %{id: id}) do
    live
    |> element("#jobs-table #job-#{id} a")
    |> render_click()
  end

  defp click_cancel(live) do
    live
    |> element("#detail-cancel")
    |> render_click()
  end

  defp click_run_now(live) do
    live
    |> element("#detail-retry")
    |> render_click()
  end
end
