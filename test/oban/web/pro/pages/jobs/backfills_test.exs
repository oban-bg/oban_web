if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Jobs.BackfillsTest do
    use Oban.Web.ProCase, async: true

    setup :start_supervised_oban!

    test "walking a backfill's windows from one to the next", %{oban: oban} do
      [first, second, third, halted] = run_backfill!(oban, 25)

      live = open_job(third)

      assert has_element?(live, "#status-backfill")
      assert has_element?(live, "dt", "Backfill")
      assert has_element?(live, "#backfill-links #backfill-prev-link[href$='/jobs/#{second.id}']")
      assert has_element?(live, "#backfill-links #backfill-next-link[href$='/jobs/#{halted.id}']")

      assert has_element?(
               live,
               "#backfill-next-link #backfill-next-link-state[data-title=completed]"
             )

      live
      |> element("#backfill-next-link")
      |> render_click()

      assert page_title(live) =~ "(#{halted.id})"
      assert has_element?(live, "#backfill-links #backfill-next-link", "Next")
      refute has_element?(live, "#backfill-links #backfill-next-link[href]")

      live
      |> element("#backfill-all-link")
      |> render_click()

      for job <- [first, second, third, halted] do
        assert has_element?(live, "#jobs-table #job-#{job.id}")
      end
    end

    defp open_job(job) do
      {:ok, live, _html} = live(build_conn(), "/oban/jobs/#{job.id}")

      live
    end
  end
end
