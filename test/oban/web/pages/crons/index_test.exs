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

  setup do
    static_crontab = [
      {"* * * * *", Oban.Workers.CronA},
      {"0 * * * *", Oban.Workers.CronA, args: %{special: true}},
      {"0 0 * * *", Oban.Workers.CronB, priority: 3}
    ]

    start_supervised_oban!(
      plugins: [
        {Oban.Plugins.Cron, crontab: static_crontab},
        {Oban.Pro.Plugins.DynamicCron, crontab: []}
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
    Oban.Pro.Plugins.DynamicCron.insert([
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

      assert_patch(live, crons_path(sort_by: mode, sort_dir: "asc"))
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
