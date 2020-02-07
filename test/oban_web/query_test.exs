defmodule ObanWeb.QueryTest do
  use ObanWeb.DataCase, async: true

  alias Oban.Job
  alias ObanWeb.{Config, Query, Repo}

  @conf Config.new(repo: Repo)

  describe "deschedule_job/2" do
    test "transitioning a job to the available state" do
      job =
        %{}
        |> Job.new(worker: FakeWorker)
        |> Repo.insert!()

      assert :ok = Query.deschedule_job(@conf, job.id)

      assert %{state: "available"} = Repo.reload!(job)
    end
  end

  describe "discard_job/2" do
    test "transitioning a job to the discarded state" do
      job =
        %{}
        |> Job.new(worker: FakeWorker)
        |> Repo.insert!()

      assert :ok = Query.discard_job(@conf, job.id)

      assert %{state: "discarded", discarded_at: at} = Repo.reload!(job)
      assert at
    end
  end
end
