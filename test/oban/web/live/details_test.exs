defmodule Oban.Web.Live.DetailsTest do
  use Oban.Web.DataCase

  import Phoenix.LiveViewTest

  alias Oban.Web.Plugins.Stats

  setup do
    start_supervised_oban!(plugins: [Stats])

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live}
  end

  test "viewing job details", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_available(live)
    open_details(live, job)

    assert page_title(live) =~ "WorkerA (#{job.id})"
  end

  test "viewing details for a job that was deleted falls back", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_available(live)

    Repo.delete!(job)

    open_details(live, job)

    refute has_element?(live, "#job-details")
  end

  test "cancelling a job from the detail view", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_available(live)
    open_details(live, job)

    assert has_element?(live, "#job-details")

    click_cancel(live)
  end

  defp open_available(live) do
    live
    |> element("#sidebar #states #state-available")
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
end
