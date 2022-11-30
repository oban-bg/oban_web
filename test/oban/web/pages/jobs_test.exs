defmodule Oban.Web.Pages.JobsTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  setup do
    start_supervised_oban!(name: Oban)

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live}
  end

  test "sorting jobs by different properties", %{live: live} do
    insert_job!([ref: 1], worker: Worker.A, state: "available", queue: "gamma")
    insert_job!([ref: 2], worker: Worker.B, state: "available", queue: "delta")
    insert_job!([ref: 3], worker: Worker.C, state: "available", queue: "alpha")

    click_state(live, "available")

    for mode <- ~w(worker queue attempt time) do
      change_sort(live, mode)

      assert_patch(live, jobs_path(limit: 20, sort_by: mode, sort_dir: "asc", state: "available"))
    end
  end

  defp change_sort(live, mode) do
    live
    |> element("#jobs-table a[rel=sort]", mode)
    |> render_click()
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #states #state-#{state}")
    |> render_click()
  end

  defp jobs_path(params) do
    "/oban/jobs?#{URI.encode_query(params)}"
  end
end
