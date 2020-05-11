defmodule ObanWeb.QueryTest do
  use ObanWeb.DataCase, async: true

  alias Oban.Job
  alias ObanWeb.{Config, Query, Repo}

  @conf Config.new(repo: Repo)

  describe "deschedule_jobs/2" do
    test "transitioning jobs to the available state" do
      job =
        %{}
        |> Job.new(worker: FakeWorker)
        |> Repo.insert!()

      assert :ok = Query.deschedule_jobs(@conf, [job.id])

      assert %{state: "available"} = Repo.reload!(job)
    end
  end
end
