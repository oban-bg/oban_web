defmodule Oban.Web.Pages.Jobs.EnqueueTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  setup do
    start_supervised_oban!()

    {:ok, live, _html} = live(build_conn(), "/oban/jobs")

    # Open the enqueue form
    live
    |> element("#enqueue-job-toggle")
    |> render_click()

    {:ok, live: live}
  end

  describe "mounting" do
    test "renders the new job form when toggle is clicked", %{live: live} do
      assert has_element?(live, "#new-job-form")
      assert has_element?(live, "#worker")
      assert has_element?(live, "#args")
      assert has_element?(live, "#queue")
    end
  end

  describe "form validation" do
    test "shows error when worker is empty", %{live: live} do
      live
      |> form("#new-job-form", %{worker: "", args: "{}"})
      |> render_change()

      assert has_element?(live, "#new-job-form", "Worker is required")
    end

    test "shows error for invalid JSON args", %{live: live} do
      live
      |> form("#new-job-form", %{worker: "MyWorker", args: "invalid"})
      |> render_change()

      assert has_element?(live, "#new-job-form", "Invalid JSON")
    end

    test "shows error for invalid JSON meta", %{live: live} do
      live
      |> element("button", "Advanced Options")
      |> render_click()

      live
      |> form("#new-job-form", %{worker: "MyWorker", args: "{}", meta: "invalid"})
      |> render_change()

      assert has_element?(live, "#new-job-form", "Invalid JSON")
    end

    test "clears error when valid input is provided", %{live: live} do
      live
      |> form("#new-job-form", %{worker: "", args: "{}"})
      |> render_change()

      assert has_element?(live, "#new-job-form", "Worker is required")

      live
      |> form("#new-job-form", %{worker: "MyApp.Worker", args: "{}"})
      |> render_change()

      refute has_element?(live, "#new-job-form", "Worker is required")
    end
  end

  describe "advanced options" do
    test "hides advanced options by default", %{live: live} do
      refute has_element?(live, "#priority")
      refute has_element?(live, "#tags")
      refute has_element?(live, "#schedule_in")
      refute has_element?(live, "#meta")
      refute has_element?(live, "#max_attempts")
    end

    test "shows advanced options when toggled", %{live: live} do
      live
      |> element("button", "Advanced Options")
      |> render_click()

      assert has_element?(live, "#priority")
      assert has_element?(live, "#tags")
      assert has_element?(live, "#schedule_in")
      assert has_element?(live, "#meta")
      assert has_element?(live, "#max_attempts")
    end
  end

  describe "job insertion" do
    test "creates job and redirects on valid submission", %{live: live} do
      live
      |> form("#new-job-form", %{worker: "MyApp.Worker", args: ~s({"foo": 1})})
      |> render_submit()

      assert [job] = Repo.all(Job)
      assert job.worker == "MyApp.Worker"
      assert job.args == %{"foo" => 1}
      assert job.queue == "default"

      assert_redirect(live, "/oban/jobs/#{job.id}")
    end

    test "creates job with advanced options", %{live: _live} do
      # Insert a job with queue "custom" so it appears in the dropdown
      insert_job!([ref: 1], queue: "custom")

      # Re-mount to pick up the new queue and open the form
      {:ok, live, _html} = live(build_conn(), "/oban/jobs")

      live
      |> element("#enqueue-job-toggle")
      |> render_click()

      live
      |> element("button", "Advanced Options")
      |> render_click()

      live
      |> form("#new-job-form", %{
        worker: "MyApp.Worker",
        args: "{}",
        queue: "custom",
        priority: "3",
        tags: "tag1, tag2",
        max_attempts: "5",
        meta: ~s({"key": "value"})
      })
      |> render_submit()

      jobs = Repo.all(Job)
      job = Enum.find(jobs, &(&1.worker == "MyApp.Worker"))
      assert job.queue == "custom"
      assert job.priority == 3
      assert job.tags == ["tag1", "tag2"]
      assert job.max_attempts == 5
      assert job.meta["key"] == "value"
    end

    test "creates job with schedule_in", %{live: live} do
      live
      |> element("button", "Advanced Options")
      |> render_click()

      live
      |> form("#new-job-form", %{
        worker: "MyApp.Worker",
        args: "{}",
        schedule_in: "60"
      })
      |> render_submit()

      assert [job] = Repo.all(Job)
      assert job.state == "scheduled"
      assert DateTime.compare(job.scheduled_at, DateTime.utc_now()) == :gt
    end
  end

  describe "worker suggestions" do
    test "shows existing workers in datalist" do
      insert_job!([ref: 1], worker: ExistingWorker)

      {:ok, live, _html} = live(build_conn(), "/oban/jobs")

      live
      |> element("#enqueue-job-toggle")
      |> render_click()

      assert has_element?(live, ~s(datalist#worker-suggestions option[value="ExistingWorker"]))
    end
  end

  describe "cancel button" do
    test "closes the form when cancel is clicked", %{live: live} do
      assert has_element?(live, "#new-job-form")

      live
      |> element("button", "Cancel")
      |> render_click()

      refute has_element?(live, "#new-job-form")
    end
  end

  describe "interaction with bulk selection" do
    test "form and bulk actions can both be visible", %{live: _live} do
      # Insert a job to select
      job = insert_job!([ref: 1], state: "available")

      # Re-mount to see the job
      {:ok, live, _html} = live(build_conn(), "/oban/jobs")

      # Click to available state to see the job
      live
      |> element("#sidebar #filter-available")
      |> render_click()

      # Open enqueue form
      live |> element("#enqueue-job-toggle") |> render_click()
      assert has_element?(live, "#new-job-form")

      # Select the job using the checkbox
      live
      |> element("#jobs-table #job-#{job.id} button[rel=check]")
      |> render_click()

      # Both should be visible
      assert has_element?(live, "#new-job-form")
      assert has_element?(live, "#bulk-actions")
    end
  end
end
