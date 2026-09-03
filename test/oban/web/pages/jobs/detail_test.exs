defmodule Oban.Web.Pages.Jobs.DetailTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  alias Oban.Web.CompensationFixture

  @compile {:no_warn_undefined, Oban.Web.CompensationFixture}

  setup context do
    name = start_supervised_oban!(Map.get(context, :oban_opts, []))

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, conf: Oban.config(name), live: live}
  end

  test "viewing job details", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_state(live, "available")
    open_details(live, job)

    assert page_title(live) =~ "WorkerA (#{job.id})"
  end

  test "naming controls and section state for assistive tech", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_state(live, "available")
    open_details(live, job)

    assert has_element?(live, "h2 #back-link")

    assert has_element?(
             live,
             "#job-data-toggle[aria-expanded=true][aria-controls=job-data-content]"
           )

    assert has_element?(live, "#errors-toggle[aria-expanded=false][aria-controls=errors-content]")
    assert has_element?(live, "#edit-toggle[aria-expanded=true][aria-controls=edit-content]")
    assert has_element?(live, "#copy-args[aria-label]")
    assert has_element?(live, "#job-history-chart[role=img][aria-label]")
  end

  test "viewing details for a job that was deleted falls back", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_state(live, "available")

    Repo.delete!(job)

    open_details(live, job)

    refute has_element?(live, "#job-details")
  end

  test "cancelling a job from the detail view", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_state(live, "available")
    open_details(live, job)

    assert has_element?(live, "#job-details")

    click_cancel(live)

    with_backoff(fn ->
      assert %{state: "cancelled"} = Repo.reload!(job)
    end)
  end

  test "immediately running a job from the detail view", %{live: live} do
    job = insert_job!([ref: 1], state: "scheduled", worker: WorkerA)

    open_state(live, "scheduled")
    open_details(live, job)

    assert has_element?(live, "#job-details")

    click_run_now(live)

    with_backoff(fn ->
      assert %{state: "available"} = Repo.reload!(job)
    end)
  end

  describe "editing jobs" do
    test "edit form is visible for editable jobs", %{live: live} do
      job = insert_job!([ref: 1], state: "available", worker: WorkerA)

      open_state(live, "available")
      open_details(live, job)

      assert has_element?(live, "#edit-toggle")
      assert has_element?(live, "#job-edit-form")
      refute has_element?(live, "#edit-hint")
    end

    test "edit form is available for all editable states", %{live: live} do
      job = insert_job!([ref: 1], state: "retryable", worker: WorkerA)

      open_state(live, "retryable")
      open_details(live, job)

      refute has_element?(live, "#edit-hint")
      assert has_element?(live, "#job-edit-form")
    end

    test "updating job fields successfully", %{live: live} do
      job =
        insert_job!([ref: 1],
          state: "available",
          worker: WorkerA,
          priority: 0,
          max_attempts: 20,
          tags: []
        )

      open_state(live, "available")
      open_details(live, job)

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

    test "removing all job tags", %{live: live} do
      job =
        insert_job!([ref: 1],
          state: "available",
          worker: WorkerA,
          tags: ["alpha", "beta"]
        )

      open_state(live, "available")
      open_details(live, job)

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

      {:ok, live, _html} = live(build_conn(), "/oban-readonly")

      open_state(live, "available")
      open_details(live, job)

      assert has_element?(live, "fieldset[disabled] #job-edit-form")

      live
      |> form("#job-edit-form", %{"worker" => "Attacker.Worker", "args" => "{}"})
      |> render_submit()

      reloaded = Repo.reload!(job)
      assert reloaded.worker == job.worker
      refute render(live) =~ "Job updated successfully"
    end

    @tag oban_opts: [queues: [alpha: 1]]
    test "keeping the current queue selectable when it isn't running", %{live: live} do
      job = insert_job!([ref: 1], state: "available", worker: WorkerA, queue: "dormant")

      flush_reporter()
      open_state(live, "available")
      open_details(live, job)

      assert has_element?(live, "#queue option[selected]", "dormant")

      live
      |> form("#job-edit-form", %{"priority" => "3"})
      |> render_submit()

      with_backoff(fn ->
        assert %{priority: 3, queue: "dormant"} = Repo.reload!(job)
      end)
    end

    test "reporting invalid input without saving", %{live: live} do
      job = insert_job!([ref: 1], state: "available", worker: WorkerA, priority: 0)

      open_state(live, "available")
      open_details(live, job)

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

    test "surfacing rejections from the engine", %{live: live} do
      job = insert_job!([ref: 1], state: "available", worker: WorkerA)

      open_state(live, "available")
      open_details(live, job)

      Repo.delete!(job)

      live
      |> form("#job-edit-form", %{"priority" => "3"})
      |> render_submit()

      assert has_element?(live, "#job-form-errors", "no longer exists")
    end

    test "accepting a scheduled time without seconds", %{live: live} do
      job = insert_job!([ref: 1], state: "scheduled", worker: WorkerA)

      open_state(live, "scheduled")
      open_details(live, job)

      live
      |> form("#job-edit-form", %{"scheduled_at" => "2030-01-02T03:04"})
      |> render_submit()

      with_backoff(fn ->
        assert %{scheduled_at: scheduled_at} = Repo.reload!(job)
        assert DateTime.compare(scheduled_at, ~U[2030-01-02 03:04:00Z]) == :eq
      end)
    end

    test "confirming before leaving with unsaved changes", %{live: live} do
      job = insert_job!([ref: 1], state: "available", worker: WorkerA)

      open_state(live, "available")
      open_details(live, job)

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

    test "tracking live changes to untouched fields while editing", %{live: live} do
      job = insert_job!([ref: 1], state: "available", worker: WorkerA)

      open_state(live, "available")
      open_details(live, job)

      live
      |> form("#job-edit-form", %{"priority" => "3"})
      |> render_change()

      assert {:ok, _job} =
               Oban.update_job(Oban, job.id, %{scheduled_at: ~U[2030-01-02 03:04:05Z]})

      send(live.pid, :refresh)

      assert has_element?(live, ~s|#scheduled_at[value="2030-01-02T03:04:05"]|)
      assert has_element?(live, ~s|#priority[value="3"]|)
      assert has_element?(live, "#detail-save:not([disabled])")
    end

    test "reseeding from the stored job after saving", %{live: live} do
      job = insert_job!([ref: 1], state: "available", worker: WorkerA, tags: [])

      open_state(live, "available")
      open_details(live, job)

      live
      |> form("#job-edit-form", %{"tags" => " alpha ,, beta "})
      |> render_submit()

      with_backoff(fn ->
        assert %{tags: ["alpha", "beta"]} = Repo.reload!(job)
      end)

      assert has_element?(live, ~s|#tags[value="alpha, beta"]|)
      assert has_element?(live, "#detail-save[disabled]")
    end

    test "updating unrelated fields does not change scheduled_at", %{live: live} do
      scheduled_at = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second)

      job =
        insert_job!([ref: 1],
          state: "scheduled",
          worker: WorkerA,
          priority: 0,
          scheduled_at: scheduled_at
        )

      open_state(live, "scheduled")
      open_details(live, job)

      live
      |> form("#job-edit-form", %{"priority" => "3"})
      |> render_submit()

      with_backoff(fn ->
        updated = Repo.reload!(job)
        assert updated.priority == 3
        assert DateTime.compare(updated.scheduled_at, scheduled_at) == :eq
      end)
    end
  end

  describe "external recorded output" do
    @describetag :pro

    test "loading output from a storage backend on demand", %{live: live} do
      payload = encode_term(%{total: 42})
      job = insert_recorded_job(live, payload, [])

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
      job = insert_recorded_job(live, nil, [])

      open_details(live, job)

      live
      |> element("#load-recorded")
      |> render_click()

      assert render_async(live) =~ "Stored output is no longer available"
      assert has_element?(live, "#load-recorded", "Try Again")
    end

    test "reporting an unreachable backend without leaking the reason", %{live: live} do
      job = insert_recorded_job(live, encode_term(%{}), error: "s3://bucket?X-Amz-Signature=sec")

      open_details(live, job)

      live
      |> element("#load-recorded")
      |> render_click()

      html = render_async(live)

      assert html =~ "Unable to reach the storage backend"
      refute html =~ "X-Amz-Signature"
    end

    test "keeping loaded output across refresh ticks", %{live: live} do
      job = insert_recorded_job(live, encode_term(%{total: 42}), [])

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

  defp insert_recorded_job(live, payload, storage_opts) do
    key = Ecto.UUID.generate()

    if payload, do: Oban.Web.StorageMock.store(key, payload)

    meta = %{
      "recorded" => true,
      "return" => key,
      "storage" => Oban.Pro.Storage.encode(Oban.Web.StorageMock, storage_opts)
    }

    job = insert_job!([ref: 1], state: "completed", worker: WorkerA, meta: meta)

    open_state(live, "completed")

    job
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "linking a compensating job to the job it rolls back", %{conf: conf, live: live} do
    saga = CompensationFixture.insert_compensated_saga!(conf)

    [comp] = CompensationFixture.compensation_steps(conf, saga)

    open_state(live, "available")
    open_details(live, comp)

    assert has_element?(live, "dt", "Rolls Back")
    assert has_element?(live, "#origin-job-link", "charge")
    refute has_element?(live, "#compensating-job-link")
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "linking a compensated job to the job rolling it back", %{conf: conf, live: live} do
    saga = CompensationFixture.insert_compensated_saga!(conf)

    CompensationFixture.finish_compensation!(conf, saga, "completed")

    open_state(live, "completed")
    open_details(live, saga.jobs["charge"])

    assert has_element?(live, "dt", "Rollback")
    assert has_element?(live, "#compensating-job-link", "completed")
  end

  test "omitting compensation links for ordinary jobs", %{live: live} do
    job = insert_job!([ref: 1], state: "available", worker: WorkerA)

    open_state(live, "available")
    open_details(live, job)

    refute has_element?(live, "#origin-job-link")
    refute has_element?(live, "#compensating-job-link")
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

  defp click_cancel(live) do
    live
    |> element("#detail-cancel")
    |> render_click()
  end

  defp click_run_now(live) do
    live
    |> element("#detail-retry")
    |> render_click()
  end
end
