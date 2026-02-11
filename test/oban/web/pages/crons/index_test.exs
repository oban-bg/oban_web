defmodule Oban.Workers.CronA do
  use Oban.Worker

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Workers.CronB do
  use Oban.Worker

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Workers.CronC do
  use Oban.Worker

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Web.Pages.Crons.IndexTest do
  use Oban.Web.Case, async: true

  @moduletag :pro

  alias Oban.Pro.Plugins.DynamicCron

  setup do
    static_crontab = [
      {"* * * * *", Oban.Workers.CronA},
      {"0 * * * *", Oban.Workers.CronA, args: %{special: true}},
      {"0 0 * * *", Oban.Workers.CronB, priority: 3}
    ]

    start_supervised_oban!(
      plugins: [
        {Oban.Plugins.Cron, crontab: static_crontab},
        {DynamicCron, crontab: []}
      ]
    )

    {:ok, live, _html} = live(build_conn(), "/oban/crons")

    {:ok, live: live}
  end

  test "viewing statically and dynamically configured crons", %{live: live} do
    refresh(live)

    table =
      live
      |> element("#crons-table")
      |> render()

    assert table =~ ~r/Oban.Workers.CronA/
    assert table =~ ~r/Oban.Workers.CronB/
  end

  test "viewing dynamically configured crons", %{live: live} do
    DynamicCron.insert([
      {"* 1 * * *", Oban.Workers.CronB},
      {"0 0 * * *", Oban.Workers.CronC}
    ])

    refresh(live)

    table =
      live
      |> element("#crons-table")
      |> render()

    assert table =~ ~r/Oban.Workers.CronB/
    assert table =~ ~r/Oban.Workers.CronC/
  end

  test "sorting crons by different properties", %{live: live} do
    refresh(live)

    assert has_element?(live, "#crons-sort")

    for mode <- ~w(worker last_run next_run schedule) do
      change_sort(live, mode)

      assert_patch(live, crons_path(limit: 20, sort_by: mode, sort_dir: "asc"))
    end
  end

  describe "new cron" do
    test "opens drawer and creates a cron with required fields", %{live: live} do
      refresh(live)

      # Click the New link to open the drawer
      live
      |> element("#new-cron-button")
      |> render_click()

      assert_patch(live, "/oban/crons/new")

      # Fill in required fields
      live
      |> form("#new-cron-form", %{
        "worker" => "Oban.Workers.CronA",
        "name" => "my-new-cron",
        "expression" => "*/5 * * * *"
      })
      |> render_submit()

      # Should redirect to crons list
      assert_patch(live, "/oban/crons")

      # Verify cron was created
      assert [entry] = DynamicCron.all(Oban) |> Enum.filter(&(&1.name == "my-new-cron"))
      assert entry.expression == "*/5 * * * *"
      assert entry.worker == "Oban.Workers.CronA"
    end

    test "creates a cron with all options including guaranteed", %{live: live} do
      refresh(live)

      live
      |> element("#new-cron-button")
      |> render_click()

      assert_patch(live, "/oban/crons/new")

      live
      |> form("#new-cron-form", %{
        "worker" => "Oban.Workers.CronB",
        "name" => "full-options-cron",
        "expression" => "0 0 * * *",
        "timezone" => "America/Chicago",
        "priority" => "2",
        "max_attempts" => "5",
        "tags" => "tag1, tag2",
        "guaranteed" => "true",
        "args" => ~s({"key": "value"})
      })
      |> render_submit()

      assert_patch(live, "/oban/crons")

      assert [entry] = Enum.filter(DynamicCron.all(), &(&1.name == "full-options-cron"))
      assert entry.expression == "0 0 * * *"
      assert entry.worker == "Oban.Workers.CronB"
      assert entry.opts["timezone"] == "America/Chicago"
      assert entry.opts["priority"] == 2
      assert entry.opts["max_attempts"] == 5
      assert entry.opts["tags"] == ["tag1", "tag2"]
      assert entry.opts["guaranteed"] == true
      assert entry.opts["args"] == %{"key" => "value"}
    end

    test "auto-generates name from worker", %{live: live} do
      refresh(live)

      live
      |> element("#new-cron-button")
      |> render_click()

      # Type in worker and check that name field updates
      html =
        live
        |> element("#new-cron-form")
        |> render_change(%{"worker" => "MyApp.Workers.SendEmail", "name" => ""})

      assert html =~ ~r/name="name"[^>]*value="send-email"/
    end

    test "closes drawer on escape key", %{live: live} do
      refresh(live)

      live
      |> element("#new-cron-button")
      |> render_click()

      assert_patch(live, "/oban/crons/new")

      live
      |> element("#new-cron")
      |> render_keydown(%{"key" => "Escape"})

      assert_patch(live, "/oban/crons")
    end
  end

  describe "pagination" do
    test "clicking Show More increases the limit", %{live: live} do
      crons = Enum.map(1..25, &{"#{&1} * * * *", Oban.Workers.CronA, name: "cron-#{&1}"})

      DynamicCron.insert(crons)

      refresh(live)

      live
      |> element("button", "Show More")
      |> render_click()

      assert_patch(live, crons_path(limit: 40))
    end

    test "hides pagination buttons when all crons fit within limit", %{live: live} do
      refresh(live)

      refute has_element?(live, "button", "Show More")
      refute has_element?(live, "button", "Show Less")
    end
  end

  defp change_sort(live, mode) do
    live
    |> element("a#sort-#{mode}")
    |> render_click()
  end

  defp crons_path(params) do
    "/oban/crons?#{URI.encode_query(params)}"
  end

  defp refresh(live) do
    send(live.pid, :refresh)
  end
end
