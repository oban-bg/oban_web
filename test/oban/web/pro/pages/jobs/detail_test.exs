if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Jobs.DetailTest do
    use Oban.Web.ProCase

    alias Oban.Web.ProFixtures.ChunkWorker
    alias Oban.Web.StorageMock

    setup context do
      start_supervised_oban!(Map.get(context, :oban_opts, []))

      {:ok, live, _html} = live(build_conn(), "/oban")

      {:ok, live: live}
    end

    describe "external recorded output" do
      setup do
        on_exit(fn -> StorageMock.reset() end)
      end

      test "loading output from a storage backend on demand", %{live: live} do
        job = run_recorded!(42)

        open_state(live, "completed")
        open_details(live, job)

        refute render(live) =~ "total: 42"
        assert has_element?(live, "#load-recorded")

        live
        |> element("#load-recorded")
        |> render_click()

        assert render_async(live) =~ "total: 42"
        assert has_element?(live, "#copy-recorded")
      end

      test "reporting output the backend no longer has", %{live: live} do
        job = run_recorded!(42)

        StorageMock.reset()

        open_state(live, "completed")
        open_details(live, job)

        live
        |> element("#load-recorded")
        |> render_click()

        assert render_async(live) =~ "Stored output is no longer available"
        assert has_element?(live, "#load-recorded", "Try Again")
      end

      test "reporting an unreachable backend without leaking the reason", %{live: live} do
        job = run_recorded!(42)

        StorageMock.break("s3://bucket?X-Amz-Signature=sec")

        open_state(live, "completed")
        open_details(live, job)

        live
        |> element("#load-recorded")
        |> render_click()

        html = render_async(live)

        assert html =~ "Unable to reach the storage backend"
        refute html =~ "X-Amz-Signature"
      end

      test "keeping loaded output across refresh ticks", %{live: live} do
        job = run_recorded!(42)

        open_state(live, "completed")
        open_details(live, job)

        live
        |> element("#load-recorded")
        |> render_click()

        assert render_async(live) =~ "total: 42"

        send(live.pid, :refresh)

        assert render(live) =~ "total: 42"
        refute has_element?(live, "#load-recorded")
      end
    end

    describe "compensation" do
      test "linking a compensating job to the job it rolls back", %{live: live} do
        saga = run_failed_saga!()

        [comp] = compensation_steps(saga)

        open_state(live, "available")
        open_details(live, comp)

        assert has_element?(live, "dt", "Rolls Back")
        assert has_element?(live, "#origin-job-link", "charge")
        refute has_element?(live, "#compensating-job-link")
      end

      test "linking a compensated job to the job rolling it back", %{live: live} do
        saga = compensate_saga!(run_failed_saga!())

        open_state(live, "completed")
        open_details(live, saga.jobs["charge"])

        assert has_element?(live, "dt", "Rollback")
        assert has_element?(live, "#compensating-job-link", "completed")
      end
    end

    describe "chunks" do
      test "linking a leader to its chunk members by state", %{live: live} do
        [leader | _siblings] =
          run_chunk!([%{ref: 1}, %{ref: 2}, %{ref: 3}, %{ref: 4, result: "error"}])

        open_state(live, "completed")
        open_details(live, leader)

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
      test "sizing a running chunk from the leader's meta", %{live: live} do
        {worker_pid, [leader | _siblings]} =
          start_blocked_chunk!([%{ref: 1}, %{ref: 2}, %{ref: 3}])

        open_state(live, "executing")
        open_details(live, leader)

        assert has_element?(live, "#chunk-members #chunk-executing-link", "3 executing")

        finish_chunk(worker_pid)
      end

      @tag oban_opts: [queues: [chunks: 1], stage_interval: 10]
      test "noting a leader that is still waiting for a full chunk", %{live: live} do
        leader = start_waiting_chunk!(%{ref: 1})

        open_state(live, "executing")
        open_details(live, leader)

        assert has_element?(live, "#chunk-members", "Waiting for a full chunk")
        refute has_element?(live, "#chunk-executing-link")
      end

      test "linking a sibling to the job that led its chunk", %{live: live} do
        [leader, sibling] = run_chunk!([%{ref: 1}, %{ref: 2}])

        open_state(live, "completed")
        open_details(live, sibling)

        assert has_element?(live, "dt", "Chunk Leader")
        assert has_element?(live, "#chunk-leader-link", inspect(ChunkWorker))
        assert has_element?(live, "#chunk-leader-link #chunk-leader-state[data-title=completed]")
        refute has_element?(live, "#chunk-members")

        live
        |> element("#chunk-leader-link")
        |> render_click()

        assert page_title(live) =~ "#{inspect(ChunkWorker)} (#{leader.id})"
      end

      test "noting a sibling whose leader was deleted", %{live: live} do
        [leader, sibling] = run_chunk!([%{ref: 1}, %{ref: 2}])

        Repo.delete!(leader)

        open_state(live, "completed")
        open_details(live, sibling)

        assert has_element?(live, "#chunk-leader-missing", "Job #{leader.id}")
        refute has_element?(live, "#chunk-leader-link")
      end
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
  end
end
