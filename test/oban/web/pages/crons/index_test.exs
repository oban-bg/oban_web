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
