defmodule Oban.Web.Live.BulkOperationsTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  setup do
    start_supervised_oban!()

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live}
  end

  test "cancelling selected jobs", %{live: live} do
    [job_1, _job, job_3] =
      Oban.insert_all([
        Job.new(%{ref: 1}, state: "available", worker: WorkerA),
        Job.new(%{ref: 2}, state: "available", worker: WorkerB),
        Job.new(%{ref: 3}, state: "available", worker: WorkerC)
      ])

    click_state(live, "available")
    select_jobs(live, [job_1, job_3])
    click_bulk_action(live, "cancel")

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
    click_bulk_action(live, "delete")

    hidden_job?(live, job_1)
    hidden_job?(live, job_3)
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #states #state-#{state}")
    |> render_click()
  end

  defp select_jobs(live, jobs) do
    for %{id: id} <- jobs do
      live
      |> element("#jobs-table #job-#{id} [rel=toggle-select]")
      |> render_click()
    end
  end

  defp click_bulk_action(live, action) do
    live
    |> element("#bulk-action #bulk-#{action}")
    |> render_click()
  end

  defp hidden_job?(live, %{id: id}) do
    refute has_element?(live, "#job-#{id}")
  end
end
