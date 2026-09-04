defmodule Oban.Workers.NewJobWorker do
  use Oban.Worker, max_attempts: 7, tags: ["from-worker"]

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Web.Pages.Jobs.NewTest do
  use Oban.Web.Case, async: true

  setup do
    oban = start_supervised_oban!()

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live, oban: oban}
  end

  describe "new job" do
    test "new button is disabled when user has read_only access" do
      {:ok, live, _html} = live(build_conn(), "/oban-readonly")

      assert has_element?(live, "#new-job-button[aria-disabled]")
    end

    test "creates a job with all options", %{live: live, oban: oban} do
      gossip(oban, node: "web-1", queue: "alpha")
      gossip(oban, node: "web-1", queue: "gamma")

      refresh(live)

      live
      |> element("#new-job-button")
      |> render_click()

      assert_patch(live, "/oban/jobs/new")

      live
      |> form("#new-job-form", %{
        "worker" => "MyApp.Workers.FullOptionsWorker",
        "args" => ~s({"key": "value"}),
        "queue" => "alpha",
        "priority" => "3",
        "max_attempts" => "5",
        "tags" => "tag1, tag2"
      })
      |> render_submit()

      job = Repo.get_by!(Job, worker: "MyApp.Workers.FullOptionsWorker")

      assert job.queue == "alpha"
      assert job.priority == 3
      assert job.max_attempts == 5
      assert job.tags == ["tag1", "tag2"]

      assert_patch(live, "/oban/jobs/#{job.id}")
    end

    test "uses the worker's new/2 when the module is available", %{live: live} do
      live
      |> element("#new-job-button")
      |> render_click()

      live
      |> form("#new-job-form", %{
        "worker" => "Oban.Workers.NewJobWorker",
        "args" => ~s({"key": "value"})
      })
      |> render_submit()

      job = Repo.get_by!(Job, worker: "Oban.Workers.NewJobWorker")

      # These defaults come from the worker's `use Oban.Worker` opts, so they are
      # only applied when the job is built through the worker's `new/2`.
      assert job.max_attempts == 7
      assert job.tags == ["from-worker"]

      assert_patch(live, "/oban/jobs/#{job.id}")
    end

    test "creates a scheduled job", %{live: live} do
      live
      |> element("#new-job-button")
      |> render_click()

      future_time =
        DateTime.utc_now()
        |> DateTime.add(3600, :second)
        |> Calendar.strftime("%Y-%m-%dT%H:%M")

      live
      |> form("#new-job-form", %{"worker" => "ScheduledWorker", "scheduled_at" => future_time})
      |> render_submit()

      job = Repo.get_by!(Job, worker: "ScheduledWorker")

      assert job.state == "scheduled"
      assert Calendar.strftime(job.scheduled_at, "%Y-%m-%dT%H:%M") == future_time

      assert_patch(live, "/oban/jobs/#{job.id}")
    end

    test "stays on drawer when args is invalid JSON", %{live: live} do
      live
      |> element("#new-job-button")
      |> render_click()

      assert_patch(live, "/oban/jobs/new")

      live
      |> form("#new-job-form", %{
        "worker" => "MyApp.Workers.InvalidJsonWorker",
        "args" => "not valid json"
      })
      |> render_submit()

      # Drawer stays open, no redirect
      assert has_element?(live, "#new-job")
      refute Repo.get_by(Job, worker: "MyApp.Workers.InvalidJsonWorker")
    end

    test "closes drawer on escape key", %{live: live} do
      live
      |> element("#new-job-button")
      |> render_click()

      assert_patch(live, "/oban/jobs/new")

      live
      |> element("#new-job")
      |> render_keydown(%{"key" => "Escape"})

      assert_patch(live, "/oban/jobs")
    end
  end

  defp refresh(live) do
    send(live.pid, :refresh)
  end
end
