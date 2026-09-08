if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Jobs.ArchiveTest do
    use Oban.Web.ProCase, async: true

    setup do
      oban = start_supervised_oban!()

      {:ok, live, _html} = live(build_conn(), "/oban")

      {:ok, live: live, oban: oban}
    end

    test "browsing, filtering, and deleting archived jobs", %{live: live} do
      now = DateTime.utc_now()

      insert_job!([ref: 1], worker: LiveWorker, state: "completed", completed_at: now)
      completed = insert_archived_job!([ref: 2], worker: ArchivedWorker)
      discarded = insert_archived_job!([ref: 3], worker: DiscardedWorker, state: "discarded")

      live
      |> element("#sidebar #states #filter-archive")
      |> render_click()

      assert_patch(live, "/oban/jobs?archive=true&state=completed")

      assert has_element?(live, "#jobs-header #jobs-source", "Archived")
      assert has_element?(live, "#sidebar #filter-archive[data-title]")
      refute has_element?(live, "#sidebar #states-header-0")
      assert has_element?(live, "#refresh-menu-toggle", "Off")
      refute has_element?(live, "#sidebar #states #filter-executing")
      refute has_element?(live, "#chart")

      assert has_element?(live, "#job-#{completed.id}", "ArchivedWorker")
      refute has_element?(live, "#jobs-table", "LiveWorker")

      live
      |> element("#sidebar #states #filter-discarded")
      |> render_click()

      assert_patch(live, "/oban/jobs?archive=true&state=discarded")
      assert has_element?(live, "#job-#{discarded.id}", "DiscardedWorker")

      live
      |> element("#jobs-table #job-#{discarded.id} button[rel=check]")
      |> render_click()

      refute has_element?(live, "#bulk-actions #cancel-jobs")

      live
      |> element("#bulk-actions #delete-jobs")
      |> render_click()

      assert [] = archived_ids([discarded.id])
      refute has_element?(live, "#job-#{discarded.id}")

      live
      |> element("#sidebar #states #filter-archive")
      |> render_click()

      assert_patch(live, "/oban/jobs?state=discarded")
      assert has_element?(live, "#jobs-header #jobs-source", "Jobs")
      assert has_element?(live, "#refresh-menu-toggle", "1s")
    end

    test "viewing and deleting an archived job", %{live: live} do
      job = insert_archived_job!([ref: 1], worker: ArchivedWorker)

      render_patch(live, "/oban/jobs/#{job.id}?archive=true")

      assert has_element?(live, "#back-link", "Archived job")
      assert has_element?(live, "#status-archived")
      assert has_element?(live, "#detail-retry[disabled]")
      refute has_element?(live, "#edit-toggle")

      live
      |> element("#detail-delete")
      |> render_click()

      assert_patch(live, "/oban/jobs?archive=true")
      assert [] = archived_ids([job.id])
    end

    defp archived_ids(ids) do
      Repo.all(from(j in {"oban_jobs_archive", Job}, where: j.id in ^ids, select: j.id))
    end
  end
end
