if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Jobs.ChunksTest do
    use Oban.Web.ProCase, async: true

    alias Oban.Web.ProFixtures.ChunkWorker

    setup :start_supervised_oban!

    test "linking a leader to its chunk members by state", %{oban: oban} do
      [leader | _siblings] =
        run_chunk!(oban, [%{ref: 1}, %{ref: 2}, %{ref: 3}, %{ref: 4, result: "error"}])

      live = open_job(leader)

      assert has_element?(live, "dt", "Chunk")
      assert has_element?(live, "#chunk-members #chunk-completed-link", "3 completed")
      assert has_element?(live, "#chunk-members #chunk-retryable-link", "1 retryable")

      live
      |> element("#chunk-retryable-link")
      |> render_click()

      assert has_element?(live, "#jobs-table [id^=job-]")
      refute has_element?(live, "#jobs-table #job-#{leader.id}")
    end

    @tag oban_opts: [queues: [chunks: 1], stage_interval: 10]
    test "sizing a running chunk from the leader's meta", %{oban: oban} do
      {worker_pid, [leader | _siblings]} =
        start_blocked_chunk!(oban, [%{ref: 1}, %{ref: 2}, %{ref: 3}])

      live = open_job(leader)

      assert has_element?(live, "#chunk-members #chunk-executing-link", "3 executing")

      finish_chunk(worker_pid)
    end

    @tag oban_opts: [queues: [chunks: 1], stage_interval: 10]
    test "noting a leader that is still waiting for a full chunk", %{oban: oban} do
      leader = start_waiting_chunk!(oban, %{ref: 1})

      live = open_job(leader)

      assert has_element?(live, "#chunk-members", "Waiting for a full chunk")
      refute has_element?(live, "#chunk-executing-link")
    end

    test "linking a sibling to the job that led its chunk", %{oban: oban} do
      [leader, sibling] = run_chunk!(oban, [%{ref: 1}, %{ref: 2}])

      live = open_job(sibling)

      assert has_element?(live, "dt", "Chunk Leader")
      assert has_element?(live, "#chunk-leader-link", inspect(ChunkWorker))
      assert has_element?(live, "#chunk-leader-link #chunk-leader-state[data-title=completed]")
      refute has_element?(live, "#chunk-members")

      live
      |> element("#chunk-leader-link")
      |> render_click()

      assert page_title(live) =~ "#{inspect(ChunkWorker)} (#{leader.id})"
    end

    test "noting a sibling whose leader was deleted", %{oban: oban} do
      [leader, sibling] = run_chunk!(oban, [%{ref: 1}, %{ref: 2}])

      Repo.delete!(leader)

      live = open_job(sibling)

      assert has_element?(live, "#chunk-leader-missing", "Job #{leader.id}")
      refute has_element?(live, "#chunk-leader-link")
    end

    defp open_job(job) do
      {:ok, live, _html} = live(build_conn(), "/oban/jobs/#{job.id}")

      live
    end
  end
end
