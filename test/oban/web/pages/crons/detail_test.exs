defmodule Oban.Workers.DetailCronWorker do
  use Oban.Worker

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Workers.DefaultsCronWorker do
  use Oban.Worker, max_attempts: 7, tags: ["from-worker"]

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Web.Pages.Crons.DetailTest do
  use Oban.Web.Case

  alias Oban.Pro.Cron
  alias Oban.Web.Utils
  alias Oban.Workers.{DefaultsCronWorker, DetailCronWorker}

  @moduletag :pro

  setup do
    start_supervised_oban!(
      plugins: [
        {Oban.Cron, crontab: [{"* * * * *", DetailCronWorker}]},
        {Cron, crontab: []}
      ]
    )

    :ok
  end

  describe "cron detail view" do
    test "displays timezone from opts or defaults to Etc/UTC" do
      Cron.insert([
        {"0 * * * *", DetailCronWorker, name: "with-tz", timezone: "America/Chicago"},
        {"0 * * * *", DetailCronWorker, name: "without-tz"}
      ])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/with-tz")

      assert refresh(live) =~ ~s(value="America/Chicago" selected)

      {:ok, live, _html} = live(build_conn(), "/oban/crons/without-tz")

      html = refresh(live)

      assert html =~ ~s(value="" selected)
      refute html =~ ~s(value="Etc/UTC" selected)
    end

    test "displays last status with correct state" do
      Cron.insert([{"*/5 * * * *", DetailCronWorker, name: "status-test"}])

      insert_job!(
        [ref: 1],
        worker: DetailCronWorker,
        state: "completed",
        meta: %{cron_name: "status-test"}
      )

      {:ok, live, _html} = live(build_conn(), "/oban/crons/status-test")

      assert refresh(live) =~ "Completed"
    end

    test "displays schedule with human-readable description" do
      Cron.insert([{"*/15 * * * *", DetailCronWorker, name: "schedule-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/schedule-test")

      html = refresh(live)

      assert html =~ "Every 15 minutes"
      assert html =~ "*/15 * * * *"

      assert has_element?(live, "h2 #back-link")
    end

    test "describing the stored schedule rather than edits in progress" do
      Cron.insert([{"*/15 * * * *", DetailCronWorker, name: "describe-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/describe-test")

      live
      |> element("#cron-form")
      |> render_change(%{"expression" => "0 9 * * 1"})

      description = live |> element("#cron-expression-description") |> render()

      assert description =~ "Every 15 minutes"
      refute description =~ "Monday"
    end

    test "labeling timezones with their current offset" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "offset-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/offset-test")

      assert has_element?(live, ~s(#timezone option[value="Etc/UTC"]), "Etc/UTC (UTC+00:00)")
      assert has_element?(live, ~s(#timezone option[value="America/Chicago"]), "(UTC-0")
    end

    test "showing the worker's own defaults as placeholders" do
      Cron.insert([
        {"0 * * * *", DetailCronWorker, name: "plain-worker"},
        {"0 * * * *", DefaultsCronWorker, name: "custom-worker"},
        {"0 * * * *", "Python.Worker", name: "foreign-worker"}
      ])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/plain-worker")

      assert has_element?(live, ~s(#max_attempts[placeholder="20"]))
      assert has_element?(live, ~s(#priority[placeholder="0"]))
      assert has_element?(live, "#queue option", "worker default (default)")

      {:ok, live, _html} = live(build_conn(), "/oban/crons/custom-worker")

      assert has_element?(live, ~s(#max_attempts[placeholder="7"]))

      {:ok, live, _html} = live(build_conn(), "/oban/crons/foreign-worker")

      assert has_element?(live, ~s(#max_attempts[placeholder="worker default"]))
      assert has_element?(live, "#queue option", "worker default")
      refute has_element?(live, "#queue option", "worker default (")
    end

    test "sizing the history window in the heading" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "window-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/window-test")

      assert live |> element("#cron-history-window") |> render() =~ "no runs yet"
    end

    test "shows dynamic badge only for dynamic crons" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "dynamic-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/dynamic-cron")

      refresh(live)
      assert has_element?(live, "#status-dynamic")
      refute has_element?(live, "#status-static")

      static_name = Utils.cron_entry_name({"* * * * *", DetailCronWorker, []})
      {:ok, live, _html} = live(build_conn(), "/oban/crons/#{static_name}")

      refresh(live)
      refute has_element?(live, "#status-dynamic")
      assert has_element?(live, "#status-static")
    end

    test "pause button toggles cron pause state" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "pause-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/pause-test")

      refresh(live)

      assert has_element?(live, "button", "Pause")
      refute has_element?(live, "button", "Resume")

      live
      |> element("button", "Pause")
      |> render_click()

      assert has_element?(live, "button", "Resume")
      refute has_element?(live, "button", "Pause")
      assert has_element?(live, "#status-paused")
      assert [%{paused: true}] = Cron.all()

      html = refresh(live)

      assert html =~ "Paused cron pause-test"
      refute html =~ ~r/Last Status.*Paused/s
    end

    test "pause button is disabled for static crons" do
      static_name = Utils.cron_entry_name({"* * * * *", DetailCronWorker, []})
      {:ok, live, _html} = live(build_conn(), "/oban/crons/#{static_name}")

      refresh(live)

      assert has_element?(live, "button[disabled]", "Pause")
    end

    test "edit form is disabled for static crons" do
      stop_supervised!(Oban)

      start_supervised_oban!(
        engine: Oban.Pro.Engine,
        plugins: [
          {Oban.Cron, crontab: [{"* * * * *", DetailCronWorker}]},
          {Cron, crontab: []}
        ]
      )

      static_name = Utils.cron_entry_name({"* * * * *", DetailCronWorker, []})
      {:ok, live, _html} = live(build_conn(), "/oban/crons/#{static_name}")

      html = refresh(live)

      assert html =~ "Move it to Pro Cron"
      assert has_element?(live, "[rel=static-blocker]")
      assert has_element?(live, "#cron-form-fields[disabled]")
      refute has_element?(live, "#detail-save")
    end

    test "edit form is enabled for dynamic crons" do
      stop_supervised!(Oban)

      start_supervised_oban!(
        engine: Oban.Pro.Engine,
        plugins: [
          {Oban.Cron, crontab: [{"* * * * *", DetailCronWorker}]},
          {Cron, crontab: []}
        ]
      )

      Cron.insert([{"0 * * * *", DetailCronWorker, name: "editable-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/editable-cron")

      refresh(live)

      refute has_element?(live, "[rel=static-blocker]")
      refute has_element?(live, "#cron-form-fields[disabled]")

      assert has_element?(live, "#detail-save[disabled]")
      assert has_element?(live, "#detail-discard[disabled]")

      live
      |> element("#cron-form")
      |> render_change(%{"priority" => "2"})

      assert has_element?(live, "#detail-save:not([disabled])")
      assert has_element?(live, "#detail-discard:not([disabled])")
    end

    test "discarding edits restores the stored values" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "discard-cron", priority: 1}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/discard-cron")

      live
      |> element("#cron-form")
      |> render_change(%{"priority" => "2", "tags" => "urgent"})

      assert render(live) =~ ~s(name="priority" value="2")

      live
      |> element("#detail-discard")
      |> render_click()

      html = render(live)

      assert html =~ ~s(name="priority" value="1")
      refute html =~ "urgent"
      assert has_element?(live, "#detail-save[disabled]")
    end

    test "keeping edits in progress while refreshes replace the cron" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "fresh-cron", priority: 1}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/fresh-cron")

      live
      |> element("#cron-form")
      |> render_change(%{"tags" => "urgent"})

      assert {:ok, _entry} = Cron.update("fresh-cron", priority: 3)

      html = refresh(live)

      assert html =~ ~s(name="priority" value="3")
      assert html =~ ~s(name="tags" value="urgent")
    end

    test "run now button inserts a job for the cron" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "run-now-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/run-now-test")

      refresh(live)

      assert has_element?(live, "button", "Run Now")

      live
      |> element("button", "Run Now")
      |> render_click()

      assert [job] = Repo.all(Job)

      assert "Oban.Workers.DetailCronWorker" == job.worker
      assert %{"cron_expr" => "0 * * * *", "cron_name" => "run-now-test"} = job.meta
    end

    test "run now builds the job through the worker's new/2 when available" do
      Cron.insert([{"0 * * * *", DefaultsCronWorker, name: "run-now-defaults"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/run-now-defaults")

      refresh(live)

      live
      |> element("button", "Run Now")
      |> render_click()

      assert [job] = Repo.all(Job)

      assert job.max_attempts == 7
      assert job.tags == ["from-worker"]
    end

    test "delete button removes dynamic cron and redirects to list" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "delete-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/delete-test")

      refresh(live)

      assert has_element?(
               live,
               ~s(#delete-cron-button[data-confirm="Delete the delete-test cron? Jobs it already inserted will still run."])
             )

      live
      |> element("button", "Delete")
      |> render_click()

      # Should redirect to crons list
      assert_patch(live, "/oban/crons")

      # Cron should be deleted
      assert [] = Cron.all(Oban)
    end

    test "delete button is disabled for static crons" do
      static_name = Utils.cron_entry_name({"* * * * *", DetailCronWorker, []})
      {:ok, live, _html} = live(build_conn(), "/oban/crons/#{static_name}")

      refresh(live)

      assert has_element?(live, "button[disabled]", "Delete")
    end

    test "editing and saving a dynamic cron" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "edit-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/edit-cron")

      live
      |> form("#cron-form", %{
        "expression" => "*/30 * * * *",
        "timezone" => "America/New_York",
        "priority" => "3",
        "max_attempts" => "10",
        "tags" => "important, nightly",
        "args" => ~s({"mode": "full", "limit": 100}),
        "guaranteed" => "true"
      })
      |> render_submit()

      assert [entry] = Enum.filter(Cron.all(), &(&1.name == "edit-cron"))
      assert entry.expression == "*/30 * * * *"
      assert entry.opts["timezone"] == "America/New_York"
      assert entry.opts["priority"] == 3
      assert entry.opts["max_attempts"] == 10
      assert entry.opts["tags"] == ["important", "nightly"]
      assert entry.opts["args"] == %{"mode" => "full", "limit" => 100}
      assert entry.opts["guaranteed"] == true
    end

    test "removing all dynamic cron tags" do
      Cron.insert([
        {"0 * * * *", DetailCronWorker, name: "clear-tags-cron", tags: ["important", "nightly"]}
      ])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/clear-tags-cron")

      live
      |> form("#cron-form", %{"tags" => ""})
      |> render_change()

      assert has_element?(live, ~s|#cron-form button[type="submit"]:not([disabled])|)

      live
      |> form("#cron-form", %{"tags" => ""})
      |> render_submit()

      assert [entry] = Enum.filter(Cron.all(), &(&1.name == "clear-tags-cron"))
      refute Map.has_key?(entry.opts, "tags")
    end

    test "clearing the queue and timezone falls back to the defaults" do
      Cron.insert([
        {"0 * * * *", DetailCronWorker,
         name: "clear-opts-cron", queue: "media", timezone: "America/Chicago", meta: %{"x" => 1}}
      ])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/clear-opts-cron")

      assert refresh(live) =~ ~s(value="media" selected)

      live
      |> form("#cron-form", %{"queue" => "", "timezone" => ""})
      |> render_submit()

      assert [entry] = Enum.filter(Cron.all(), &(&1.name == "clear-opts-cron"))
      assert entry.opts == %{"meta" => %{"x" => 1}}
    end

    test "rejecting args that aren't a JSON object" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "bad-args-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/bad-args-cron")

      live
      |> form("#cron-form", %{"args" => "[1, 2]"})
      |> render_submit()

      assert live |> element("#cron-form-errors") |> render() =~ "Args must be a JSON object"

      live
      |> form("#cron-form", %{"args" => "{not json"})
      |> render_submit()

      assert live |> element("#cron-form-errors") |> render() =~ "Args must be valid JSON"
    end

    test "rejecting an expression that can't be parsed" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "bad-expr-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/bad-expr-cron")

      live
      |> form("#cron-form", %{"expression" => "99 * * * *"})
      |> render_submit()

      assert live |> element("#cron-form-errors") |> render() =~ "valid cron expression"

      assert [entry] = Enum.filter(Cron.all(), &(&1.name == "bad-expr-cron"))
      assert entry.expression == "0 * * * *"
    end

    test "guarding the jobs link while there are unsaved edits" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "guard-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/guard-cron")

      refute has_element?(live, "#cron-view-jobs[data-confirm]")
      assert has_element?(live, "#detail-save[phx-disable-with]")

      live
      |> element("#cron-form")
      |> render_change(%{"priority" => "3"})

      assert has_element?(live, "#cron-view-jobs[data-confirm]")
    end

    test "warning about consequences that aren't visible from the fields" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "advise-cron", guaranteed: true}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/advise-cron")

      refute has_element?(live, "#cron-form-advisories")

      live
      |> element("#cron-form")
      |> render_change(%{"priority" => "3"})

      refute has_element?(live, "#cron-form-advisories")

      live
      |> element("#cron-form")
      |> render_change(%{"expression" => "30 * * * *"})

      assert has_element?(live, "#cron-form-advisories", "Saving a new schedule")

      live
      |> element("#cron-form")
      |> render_change(%{"expression" => "0 * * * *", "name" => "renamed-cron"})

      html = render(live)

      assert html =~ "starts a fresh history"
      refute html =~ "Saving a new schedule"
    end

    test "skipping the schedule warning without guaranteed insertion" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "plain-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/plain-cron")

      live
      |> element("#cron-form")
      |> render_change(%{"timezone" => "America/Chicago"})

      refute has_element?(live, "#cron-form-advisories")
    end

    test "renaming a cron reopens it at the new address" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "old-name"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/old-name")

      live
      |> form("#cron-form", %{"name" => "new-name"})
      |> render_submit()

      assert_patch(live, "/oban/crons/new-name")

      assert render(live) =~ ~s(name="name" value="new-name")
      assert has_element?(live, "#detail-save[disabled]")
      assert [%{name: "new-name"}] = Cron.all()
    end
  end

  describe "read only access" do
    test "disabling every mutating control" do
      Cron.insert([{"0 * * * *", DetailCronWorker, name: "readonly-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban-readonly/crons/readonly-cron")

      refresh(live)

      assert live |> element("#run-now-button") |> render() =~ "disabled"
      assert live |> element("#toggle-pause-button") |> render() =~ "disabled"
      assert live |> element("#delete-cron-button") |> render() =~ "disabled"

      assert has_element?(live, "#cron-form-fields[disabled]")
      refute has_element?(live, "#detail-save")
    end
  end

  defp refresh(live) do
    send(live.pid, :refresh)

    render(live)
  end
end
