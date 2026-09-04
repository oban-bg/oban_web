defmodule Oban.Web.Pages.Jobs.EditTest do
  use Oban.Web.Case, async: true

  setup :start_supervised_oban!

  test "edit form is visible for editable jobs" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    live = open_job(job)

    assert has_element?(live, "#edit-toggle")
    assert has_element?(live, "#job-edit-form")
    refute has_element?(live, "#edit-hint")
  end

  test "edit form is available for all editable states" do
    job = insert_job!([ref: 1], state: "retryable", worker: WorkerA)

    live = open_job(job)

    refute has_element?(live, "#edit-hint")
    assert has_element?(live, "#job-edit-form")
  end

  test "updating job fields successfully" do
    job =
      insert_job!([ref: 1],
        state: "available",
        worker: WorkerA,
        priority: 0,
        max_attempts: 20,
        tags: []
      )

    live = open_job(job)

    live
    |> form("#job-edit-form", %{
      "priority" => "5",
      "max_attempts" => "10",
      "tags" => "alpha, beta"
    })
    |> render_submit()

    with_backoff(fn ->
      updated = Repo.reload!(job)
      assert updated.priority == 5
      assert updated.max_attempts == 10
      assert updated.tags == ["alpha", "beta"]
    end)

    assert render(live) =~ "Job updated successfully"
  end

  test "removing all job tags" do
    job =
      insert_job!([ref: 1],
        state: "available",
        worker: WorkerA,
        tags: ["alpha", "beta"]
      )

    live = open_job(job)

    live
    |> form("#job-edit-form", %{"tags" => ""})
    |> render_change()

    assert has_element?(live, ~s|#job-edit-form button[type="submit"]:not([disabled])|)

    live
    |> form("#job-edit-form", %{"tags" => ""})
    |> render_submit()

    with_backoff(fn ->
      assert %{tags: []} = Repo.reload!(job)
    end)
  end

  test "read-only users cannot submit edits or rewrite the worker" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    live = open_job(job, "/oban-readonly")

    assert has_element?(live, "fieldset[disabled] #job-edit-form")

    live
    |> form("#job-edit-form", %{"worker" => "Attacker.Worker", "args" => "{}"})
    |> render_submit()

    reloaded = Repo.reload!(job)
    assert reloaded.worker == job.worker
    refute render(live) =~ "Job updated successfully"
  end

  @tag oban_opts: [queues: [alpha: 1]]
  test "keeping the current queue selectable when it isn't running", %{oban: oban} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA, queue: "dormant")

    flush_reporter(oban)
    live = open_job(job)

    assert has_element?(live, "#queue option[selected]", "dormant")

    live
    |> form("#job-edit-form", %{"priority" => "3"})
    |> render_submit()

    with_backoff(fn ->
      assert %{priority: 3, queue: "dormant"} = Repo.reload!(job)
    end)
  end

  test "reporting invalid input without saving" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA, priority: 0)

    live = open_job(job)

    live
    |> form("#job-edit-form", %{"args" => "not json", "priority" => "3"})
    |> render_submit()

    assert has_element?(live, "#job-form-errors", "Args must be valid JSON")
    assert has_element?(live, ~s|#args[aria-invalid="true"]|)
    assert has_element?(live, "#job-edit-form", "not json")

    assert %{priority: 0} = Repo.reload!(job)

    live
    |> form("#job-edit-form", %{"args" => "{}", "priority" => "11"})
    |> render_submit()

    assert has_element?(live, "#job-form-errors", "Priority must be a number from 0 to 9")
    assert has_element?(live, ~s|#priority[aria-invalid="true"]|)
    refute has_element?(live, ~s|#args[aria-invalid="true"]|)

    assert %{priority: 0} = Repo.reload!(job)
  end

  test "surfacing rejections from the engine" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    live = open_job(job)

    Repo.delete!(job)

    live
    |> form("#job-edit-form", %{"priority" => "3"})
    |> render_submit()

    assert has_element?(live, "#job-form-errors", "no longer exists")
  end

  test "accepting a scheduled time without seconds" do
    job = insert_job!([ref: 1], state: "scheduled", worker: WorkerA)

    live = open_job(job)

    live
    |> form("#job-edit-form", %{"scheduled_at" => "2030-01-02T03:04"})
    |> render_submit()

    with_backoff(fn ->
      assert %{scheduled_at: scheduled_at} = Repo.reload!(job)
      assert DateTime.compare(scheduled_at, ~U[2030-01-02 03:04:00Z]) == :eq
    end)
  end

  test "confirming before leaving with unsaved changes" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    live = open_job(job)

    refute has_element?(live, "#back-link[data-confirm-back]")
    refute has_element?(live, "#queue-link[data-confirm]")

    live
    |> form("#job-edit-form", %{"priority" => "3"})
    |> render_change()

    assert has_element?(live, "#back-link[data-confirm-back]")
    assert has_element?(live, "#queue-link[data-confirm]")

    live
    |> element("#detail-discard")
    |> render_click()

    refute has_element?(live, "#back-link[data-confirm-back]")
    assert has_element?(live, ~s|#priority[value="0"]|)
  end

  test "tracking live changes to untouched fields while editing", %{oban: oban} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    live = open_job(job)

    live
    |> form("#job-edit-form", %{"priority" => "3"})
    |> render_change()

    assert {:ok, _job} =
             Oban.update_job(oban, job.id, %{scheduled_at: ~U[2030-01-02 03:04:05Z]})

    send(live.pid, :refresh)

    assert has_element?(live, ~s|#scheduled_at[value="2030-01-02T03:04:05"]|)
    assert has_element?(live, ~s|#priority[value="3"]|)
    assert has_element?(live, "#detail-save:not([disabled])")
  end

  test "reseeding from the stored job after saving" do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA, tags: [])

    live = open_job(job)

    live
    |> form("#job-edit-form", %{"tags" => " alpha ,, beta "})
    |> render_submit()

    with_backoff(fn ->
      assert %{tags: ["alpha", "beta"]} = Repo.reload!(job)
    end)

    assert has_element?(live, ~s|#tags[value="alpha, beta"]|)
    assert has_element?(live, "#detail-save[disabled]")
  end

  test "updating unrelated fields does not change scheduled_at" do
    scheduled_at = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second)

    job =
      insert_job!([ref: 1],
        state: "scheduled",
        worker: WorkerA,
        priority: 0,
        scheduled_at: scheduled_at
      )

    live = open_job(job)

    live
    |> form("#job-edit-form", %{"priority" => "3"})
    |> render_submit()

    with_backoff(fn ->
      updated = Repo.reload!(job)
      assert updated.priority == 3
      assert DateTime.compare(updated.scheduled_at, scheduled_at) == :eq
    end)
  end

  defp open_job(job, prefix \\ "/oban") do
    {:ok, live, _html} = live(build_conn(), "#{prefix}/jobs/#{job.id}")

    live
  end
end
