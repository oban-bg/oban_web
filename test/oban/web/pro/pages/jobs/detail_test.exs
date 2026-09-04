if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Jobs.DetailTest do
    use Oban.Web.ProCase, async: true

    alias Oban.Web.StorageMock

    setup :start_supervised_oban!

    describe "external recorded output" do
      test "loading output from a storage backend on demand", %{oban: oban} do
        job = run_recorded!(oban, 42)

        live = open_job(job)

        refute render(live) =~ "total: 42"
        assert has_element?(live, "#load-recorded")

        live
        |> element("#load-recorded")
        |> render_click()

        assert render_async(live) =~ "total: 42"
        assert has_element?(live, "#copy-recorded")
      end

      test "reporting output the backend no longer has", %{oban: oban} do
        job = run_recorded!(oban, 42)

        StorageMock.forget(job)

        live = open_job(job)

        live
        |> element("#load-recorded")
        |> render_click()

        assert render_async(live) =~ "Stored output is no longer available"
        assert has_element?(live, "#load-recorded", "Try Again")
      end

      test "reporting an unreachable backend without leaking the reason", %{oban: oban} do
        job = run_recorded!(oban, 42)

        StorageMock.break(job, "s3://bucket?X-Amz-Signature=sec")

        live = open_job(job)

        live
        |> element("#load-recorded")
        |> render_click()

        html = render_async(live)

        assert html =~ "Unable to reach the storage backend"
        refute html =~ "X-Amz-Signature"
      end

      test "keeping loaded output across refresh ticks", %{oban: oban} do
        job = run_recorded!(oban, 42)

        live = open_job(job)

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
      test "linking a compensating job to the job it rolls back", %{oban: oban} do
        saga = run_failed_saga!(oban)

        [comp] = compensation_steps(saga)

        live = open_job(comp)

        assert has_element?(live, "dt", "Rolls Back")
        assert has_element?(live, "#origin-job-link", "charge")
        refute has_element?(live, "#compensating-job-link")
      end

      test "linking a compensated job to the job rolling it back", %{oban: oban} do
        saga = compensate_saga!(run_failed_saga!(oban))

        live = open_job(saga.jobs["charge"])

        assert has_element?(live, "dt", "Rollback")
        assert has_element?(live, "#compensating-job-link", "completed")
      end
    end

    defp open_job(job) do
      {:ok, live, _html} = live(build_conn(), "/oban/jobs/#{job.id}")

      live
    end
  end
end
