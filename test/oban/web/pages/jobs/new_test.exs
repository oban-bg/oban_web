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

    test "surfacing errors without creating", %{live: live} do
      live
      |> element("#new-job-button")
      |> render_click()

      live
      |> form("#new-job-form", %{"worker" => "MyApp.Workers.Invalid", "args" => "not json"})
      |> render_submit()

      assert live |> element("#new-job-errors") |> render() =~ "Args must be valid JSON"
      assert has_element?(live, "#args[aria-invalid]")

      live
      |> form("#new-job-form", %{"args" => "{}", "priority" => "12"})
      |> render_submit()

      assert live |> element("#new-job-errors") |> render() =~ "Priority must be a number"
      assert has_element?(live, "#priority[aria-invalid]")
      refute has_element?(live, "#args[aria-invalid]")

      refute Repo.get_by(Job, worker: "MyApp.Workers.Invalid")
    end

    test "confirming before discarding edits", %{live: live} do
      live
      |> element("#new-job-button")
      |> render_click()

      refute live |> element("#new-job-close") |> render() =~ "data-confirm"

      live
      |> form("#new-job-form", %{"worker" => "MyApp.Workers.Draft"})
      |> render_change()

      assert live |> element("#new-job-close") |> render() =~ "Discard this unsaved job?"
      assert live |> element("#new-job-bg") |> render() =~ "Discard this unsaved job?"

      live
      |> element("#new-job-close")
      |> render_click()

      assert_patch(live, "/oban/jobs")
    end
  end

  defp refresh(live) do
    send(live.pid, :refresh)
  end
end
