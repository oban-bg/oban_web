defmodule Oban.Workers.StaticCronA do
  use Oban.Worker

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Workers.StaticCronB do
  use Oban.Worker

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Web.Pages.Crons.IndexTest do
  use Oban.Web.Case, async: true

  alias Oban.Web.Utils
  alias Oban.Workers.{StaticCronA, StaticCronB}

  setup do
    crontab = [
      {"* * * * *", StaticCronA},
      {"@reboot", StaticCronA},
      {"0 0 * * *", StaticCronB, priority: 3},
      {"0 9 * * *", StaticCronB, timezone: "America/Chicago"}
    ]

    start_supervised_oban!(plugins: [{Oban.Cron, crontab: crontab}])

    {:ok, live, _html} = live(build_conn(), "/oban/crons")

    {:ok, live: live}
  end

  test "viewing statically configured crons", %{live: live} do
    refresh(live)

    table =
      live
      |> element("#crons-table")
      |> render()

    assert table =~ "Oban.Workers.StaticCronA"
    assert table =~ "Oban.Workers.StaticCronB"
    assert table =~ "0 0 * * *"
  end

  test "distinguishing an empty filter match from having no crons", %{live: live} do
    render_patch(live, "/oban/crons?names=missing")

    html = refresh(live)

    assert html =~ "No crons match the current filters"
    refute html =~ "Crons run jobs on a schedule"

    live
    |> element("#crons-no-matches a", "Clear filters")
    |> render_click()

    assert_patch(live, "/oban/crons")
    assert refresh(live) =~ "StaticCronA"
  end

  test "sorting crons by different properties", %{live: live} do
    refresh(live)

    assert has_element?(live, "#crons-sort")

    for mode <- ~w(name last_run next_run schedule) do
      live
      |> element("#sort-#{mode}")
      |> render_click()

      assert_patch(
        live,
        "/oban/crons?#{URI.encode_query(sort_by: mode, sort_dir: "asc")}"
      )
    end

    refute has_element?(live, "#sort-worker")
  end

  test "keeping entries that share a worker in a stable order", %{live: live} do
    render_patch(live, "/oban/crons?sort_by=name&sort_dir=asc")

    rows =
      ~r/<li id="cron-([^"]+)"/
      |> Regex.scan(refresh(live))
      |> Enum.map(fn [_match, name] -> name end)

    every_minute = Utils.cron_entry_name({"* * * * *", StaticCronA, []})
    reboot = Utils.cron_entry_name({"@reboot", StaticCronA, []})

    assert Enum.take(rows, 2) == Enum.sort([every_minute, reboot])
  end

  test "ordering schedules by how often they run", %{live: live} do
    render_patch(live, "/oban/crons?sort_by=schedule&sort_dir=asc")

    rows =
      ~r/<li id="cron-([^"]+)"/
      |> Regex.scan(refresh(live))
      |> Enum.map(fn [_match, name] -> name end)

    assert List.first(rows) == Utils.cron_entry_name({"* * * * *", StaticCronA, []})
    assert List.last(rows) == Utils.cron_entry_name({"@reboot", StaticCronA, []})
  end

  test "evaluating the next run in the entry's timezone", %{live: live} do
    refresh(live)

    name = Utils.cron_entry_name({"0 9 * * *", StaticCronB, timezone: "America/Chicago"})

    cell =
      live
      |> element("#cron-nts-#{name}")
      |> render()

    assert [_, timestamp] = Regex.run(~r/data-timestamp="(\d+)"/, cell)

    next_at =
      timestamp
      |> String.to_integer()
      |> DateTime.from_unix!(:millisecond)
      |> DateTime.shift_zone!("America/Chicago")

    assert next_at.hour == 9
  end

  test "showing that a reboot cron has no scheduled run", %{live: live} do
    refresh(live)

    name = Utils.cron_entry_name({"@reboot", StaticCronA, []})

    assert has_element?(live, "#cron-nts-#{name}", "at reboot")
  end

  test "naming the last job's state and exact time for each cron", %{live: live} do
    name = Utils.cron_entry_name({"* * * * *", StaticCronA, []})

    insert_job!([ref: 1], worker: StaticCronA, state: "completed", meta: %{cron_name: name})

    refresh(live)

    assert has_element?(live, "#cron-state-icon-#{name} .sr-only", "Last job was completed")
    assert has_element?(live, "#sparkline-#{name}[aria-label='Last run: 1 completed']")
    assert has_element?(live, "#cron-lts-#{name} .sr-only", "last run")
    assert has_element?(live, "#cron-nts-#{name} .sr-only", "next run")
    assert has_element?(live, "#cron-#{name} .sr-only", "schedule")

    assert live
           |> element("#cron-lts-#{name}")
           |> render() =~ ~r/data-title="\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} UTC"/

    zoned = Utils.cron_entry_name({"0 9 * * *", StaticCronB, timezone: "America/Chicago"})

    assert has_element?(live, "#cron-state-icon-#{zoned} .sr-only", "No previous jobs")
    assert has_element?(live, "#sparkline-#{zoned}[aria-label='No runs yet']")
    assert has_element?(live, "#cron-lts-#{zoned} .sr-only", "no last run")

    assert live
           |> element("#cron-nts-#{zoned}")
           |> render() =~ ~r/data-title="[^"]+ UTC \(09:00:00 C[DS]T\)"/
  end

  test "opening a cron's details from the table", %{live: live} do
    refresh(live)

    name = Utils.cron_entry_name({"* * * * *", StaticCronA, []})

    live
    |> element("#cron-#{name} a")
    |> render_click()

    assert_patch(live, "/oban/crons/#{URI.encode_www_form(name)}")
  end

  defp refresh(live) do
    send(live.pid, :refresh)

    render(live)
  end
end
