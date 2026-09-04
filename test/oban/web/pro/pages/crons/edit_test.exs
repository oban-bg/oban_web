if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Workers.EditCronWorker do
    use Oban.Worker

    @impl true
    def perform(_job), do: :ok
  end

  defmodule Oban.Web.Pro.Pages.Crons.EditTest do
    use Oban.Web.ProCase, async: true

    alias Oban.Pro.Cron
    alias Oban.Web.Utils
    alias Oban.Workers.EditCronWorker

    setup do
      oban =
        start_supervised_oban!(
          plugins: [
            {Oban.Cron, crontab: [{"* * * * *", EditCronWorker}]},
            {Cron, crontab: []}
          ]
        )

      {:ok, oban: oban}
    end

    test "edit form is disabled for static crons" do
      static_name = Utils.cron_entry_name({"* * * * *", EditCronWorker, []})
      {:ok, live, _html} = live(build_conn(), "/oban/crons/#{static_name}")

      html = refresh(live)

      assert html =~ "Move it to Pro Cron"
      assert has_element?(live, "[rel=static-blocker]")
      assert has_element?(live, "#cron-form-fields[disabled]")
      refute has_element?(live, "#detail-save")
    end

    test "edit form is enabled for dynamic crons", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "editable-cron"}])

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

    test "discarding edits restores the stored values", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "discard-cron", priority: 1}])

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

    test "keeping edits in progress while refreshes replace the cron", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "fresh-cron", priority: 1}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/fresh-cron")

      live
      |> element("#cron-form")
      |> render_change(%{"tags" => "urgent"})

      assert {:ok, _entry} = Cron.update(oban, "fresh-cron", priority: 3)

      html = refresh(live)

      assert html =~ ~s(name="priority" value="3")
      assert html =~ ~s(name="tags" value="urgent")
    end

    test "editing and saving a dynamic cron", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "edit-cron"}])

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

      assert [entry] = Enum.filter(Cron.all(oban), &(&1.name == "edit-cron"))
      assert entry.expression == "*/30 * * * *"
      assert entry.opts["timezone"] == "America/New_York"
      assert entry.opts["priority"] == 3
      assert entry.opts["max_attempts"] == 10
      assert entry.opts["tags"] == ["important", "nightly"]
      assert entry.opts["args"] == %{"mode" => "full", "limit" => 100}
      assert entry.opts["guaranteed"] == true
    end

    test "removing all dynamic cron tags", %{oban: oban} do
      Cron.insert(oban, [
        {"0 * * * *", EditCronWorker, name: "clear-tags-cron", tags: ["important", "nightly"]}
      ])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/clear-tags-cron")

      live
      |> form("#cron-form", %{"tags" => ""})
      |> render_change()

      assert has_element?(live, ~s|#cron-form button[type="submit"]:not([disabled])|)

      live
      |> form("#cron-form", %{"tags" => ""})
      |> render_submit()

      assert [entry] = Enum.filter(Cron.all(oban), &(&1.name == "clear-tags-cron"))
      refute Map.has_key?(entry.opts, "tags")
    end

    test "clearing the queue and timezone falls back to the defaults", %{oban: oban} do
      Cron.insert(oban, [
        {"0 * * * *", EditCronWorker,
         name: "clear-opts-cron", queue: "media", timezone: "America/Chicago", meta: %{"x" => 1}}
      ])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/clear-opts-cron")

      assert refresh(live) =~ ~s(value="media" selected)

      live
      |> form("#cron-form", %{"queue" => "", "timezone" => ""})
      |> render_submit()

      assert [entry] = Enum.filter(Cron.all(oban), &(&1.name == "clear-opts-cron"))
      assert entry.opts == %{"meta" => %{"x" => 1}}
    end

    test "rejecting args that aren't a JSON object", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "bad-args-cron"}])

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

    test "rejecting an expression that can't be parsed", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "bad-expr-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/bad-expr-cron")

      live
      |> form("#cron-form", %{"expression" => "99 * * * *"})
      |> render_submit()

      assert live |> element("#cron-form-errors") |> render() =~ "valid cron expression"

      assert [entry] = Enum.filter(Cron.all(oban), &(&1.name == "bad-expr-cron"))
      assert entry.expression == "0 * * * *"
    end

    test "guarding the jobs link while there are unsaved edits", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "guard-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/guard-cron")

      refute has_element?(live, "#cron-view-jobs[data-confirm]")
      assert has_element?(live, "#detail-save[phx-disable-with]")

      live
      |> element("#cron-form")
      |> render_change(%{"priority" => "3"})

      assert has_element?(live, "#cron-view-jobs[data-confirm]")
    end

    test "warning about consequences that aren't visible from the fields", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "advise-cron", guaranteed: true}])

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

    test "skipping the schedule warning without guaranteed insertion", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "plain-cron"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/plain-cron")

      live
      |> element("#cron-form")
      |> render_change(%{"timezone" => "America/Chicago"})

      refute has_element?(live, "#cron-form-advisories")
    end

    test "renaming a cron reopens it at the new address", %{oban: oban} do
      Cron.insert(oban, [{"0 * * * *", EditCronWorker, name: "old-name"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/old-name")

      live
      |> form("#cron-form", %{"name" => "new-name"})
      |> render_submit()

      assert_patch(live, "/oban/crons/new-name")

      assert render(live) =~ ~s(name="name" value="new-name")
      assert has_element?(live, "#detail-save[disabled]")
      assert [%{name: "new-name"}] = Cron.all(oban)
    end

    defp refresh(live) do
      send(live.pid, :refresh)

      render(live)
    end
  end
end
