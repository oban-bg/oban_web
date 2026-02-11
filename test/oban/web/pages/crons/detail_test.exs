defmodule Oban.Workers.DetailCronWorker do
  use Oban.Worker

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Web.Pages.Crons.DetailTest do
  use Oban.Web.Case

  @moduletag :pro

  alias Oban.Pro.Plugins.DynamicCron
  alias Oban.Workers.DetailCronWorker

  setup do
    start_supervised_oban!(
      plugins: [
        {Oban.Plugins.Cron, crontab: [{"* * * * *", DetailCronWorker}]},
        {DynamicCron, crontab: []}
      ]
    )

    :ok
  end

  describe "cron detail view" do
    test "displays timezone from opts or defaults to Etc/UTC" do
      DynamicCron.insert([
        {"0 * * * *", DetailCronWorker, name: "with-tz", timezone: "America/Chicago"},
        {"0 * * * *", DetailCronWorker, name: "without-tz"}
      ])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/with-tz")

      assert refresh(live) =~ "America/Chicago"

      {:ok, live, _html} = live(build_conn(), "/oban/crons/without-tz")

      assert refresh(live) =~ "Etc/UTC"
    end

    test "displays last status with correct state" do
      DynamicCron.insert([{"*/5 * * * *", DetailCronWorker, name: "status-test"}])

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
      DynamicCron.insert([{"*/15 * * * *", DetailCronWorker, name: "schedule-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/schedule-test")

      html = refresh(live)

      assert html =~ "Every 15 minutes"
      assert html =~ "*/15 * * * *"
    end

    test "shows dynamic badge only for dynamic crons" do
      DynamicCron.insert([{"0 * * * *", DetailCronWorker, name: "dynamic-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/dynamic-cron")

      refresh(live)
      assert has_element?(live, "span.bg-violet-100", "Dynamic")

      static_name = Oban.Plugins.Cron.entry_name({"* * * * *", DetailCronWorker, []})
      {:ok, live, _html} = live(build_conn(), "/oban/crons/#{static_name}")

      refresh(live)
      refute has_element?(live, "span.bg-violet-100", "Dynamic")
    end

    test "pause button toggles cron pause state" do
      DynamicCron.insert([{"0 * * * *", DetailCronWorker, name: "pause-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/pause-test")

      refresh(live)

      assert has_element?(live, "button", "Pause")
      refute has_element?(live, "button", "Resume")

      live
      |> element("button", "Pause")
      |> render_click()

      assert has_element?(live, "button", "Resume")
      refute has_element?(live, "button", "Pause")
    end

    test "pause button not shown for static crons" do
      static_name = Oban.Plugins.Cron.entry_name({"* * * * *", DetailCronWorker, []})
      {:ok, live, _html} = live(build_conn(), "/oban/crons/#{static_name}")

      refresh(live)

      refute has_element?(live, "button", "Pause")
      refute has_element?(live, "button", "Resume")
    end

    test "edit form is disabled for static crons" do
      stop_supervised!(Oban)

      start_supervised_oban!(
        engine: Oban.Pro.Engines.Smart,
        plugins: [
          {Oban.Plugins.Cron, crontab: [{"* * * * *", DetailCronWorker}]},
          {DynamicCron, crontab: []}
        ]
      )

      static_name = Oban.Plugins.Cron.entry_name({"* * * * *", DetailCronWorker, []})
      {:ok, live, _html} = live(build_conn(), "/oban/crons/#{static_name}")

      html = refresh(live)

      assert html =~ "Dynamic Only"
      assert has_element?(live, "[rel=static-blocker]")
      assert has_element?(live, "fieldset[disabled]")
      assert has_element?(live, "button[disabled]", "Save Changes")
    end

    test "edit form is enabled for dynamic crons" do
      stop_supervised!(Oban)

      start_supervised_oban!(
        engine: Oban.Pro.Engines.Smart,
        plugins: [
          {Oban.Plugins.Cron, crontab: [{"* * * * *", DetailCronWorker}]},
          {DynamicCron, crontab: []}
        ]
      )

      DynamicCron.insert([{"0 * * * *", DetailCronWorker, name: "editable-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/editable-cron")

      refresh(live)

      refute has_element?(live, "[rel=static-blocker]")
      refute has_element?(live, "fieldset[disabled]")
      assert has_element?(live, "button:not([disabled])", "Save Changes")
    end

    test "run now button inserts a job for the cron" do
      DynamicCron.insert([{"0 * * * *", DetailCronWorker, name: "run-now-test"}])

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

    test "delete button removes dynamic cron and redirects to list" do
      DynamicCron.insert([{"0 * * * *", DetailCronWorker, name: "delete-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/delete-test")

      refresh(live)

      assert has_element?(live, "button", "Delete")

      live
      |> element("button", "Delete")
      |> render_click()

      # Should redirect to crons list
      assert_patch(live, "/oban/crons")

      # Cron should be deleted
      assert [] = DynamicCron.all(Oban)
    end

    test "delete button not shown for static crons" do
      static_name = Oban.Plugins.Cron.entry_name({"* * * * *", DetailCronWorker, []})
      {:ok, live, _html} = live(build_conn(), "/oban/crons/#{static_name}")

      refresh(live)

      refute has_element?(live, "button", "Delete")
    end

    test "editing and saving a dynamic cron" do
      DynamicCron.insert([{"0 * * * *", DetailCronWorker, name: "edit-cron"}])

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

      assert [entry] = Enum.filter(DynamicCron.all(), &(&1.name == "edit-cron"))
      assert entry.expression == "*/30 * * * *"
      assert entry.opts["timezone"] == "America/New_York"
      assert entry.opts["priority"] == 3
      assert entry.opts["max_attempts"] == 10
      assert entry.opts["tags"] == ["important", "nightly"]
      assert entry.opts["args"] == %{"mode" => "full", "limit" => 100}
      assert entry.opts["guaranteed"] == true
    end
  end

  defp refresh(live) do
    send(live.pid, :refresh)

    render(live)
  end
end
