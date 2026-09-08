if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Jobs.ChainsTest do
    use Oban.Web.ProCase, async: true

    setup :start_supervised_oban!

    test "walking a chain from job to job and out to the whole chain", %{oban: oban} do
      [first, middle, last] = run_chain!(oban, [%{ref: 1}, %{ref: 2}, %{ref: 3, result: "error"}])

      live = open_job(middle)

      assert has_element?(live, "#status-chain")
      assert has_element?(live, "dt", "Chain")
      assert has_element?(live, "#chain-links #chain-prev-link[href$='/jobs/#{first.id}']")
      assert has_element?(live, "#chain-prev-link #chain-prev-link-state[data-title=completed]")
      assert has_element?(live, "#chain-links #chain-next-link[href$='/jobs/#{last.id}']")
      assert has_element?(live, "#chain-next-link #chain-next-link-state[data-title=discarded]")

      live
      |> element("#chain-next-link")
      |> render_click()

      assert page_title(live) =~ "(#{last.id})"
      assert has_element?(live, "#chain-links #chain-prev-link[href$='/jobs/#{middle.id}']")
      assert has_element?(live, "#chain-links #chain-next-link", "Next")
      refute has_element?(live, "#chain-links #chain-next-link[href]")

      live
      |> element("#chain-prev-link")
      |> render_click()

      live
      |> element("#chain-prev-link")
      |> render_click()

      assert page_title(live) =~ "(#{first.id})"
      assert has_element?(live, "#chain-links #chain-prev-link", "Prev")
      refute has_element?(live, "#chain-links #chain-prev-link[href]")

      live
      |> element("#chain-all-link")
      |> render_click()

      assert has_element?(live, "#jobs-table #job-#{first.id}")
      assert has_element?(live, "#jobs-table #job-#{middle.id}")
      refute has_element?(live, "#jobs-table #job-#{last.id}")
    end

    defp open_job(job) do
      {:ok, live, _html} = live(build_conn(), "/oban/jobs/#{job.id}")

      live
    end
  end
end
