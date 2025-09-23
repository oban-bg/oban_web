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

defmodule Oban.Web.Pages.Crons.IndexTest do
  use Oban.Web.Case, async: true

  setup do
    start_supervised_oban!(
      plugins: [
        {Oban.Plugins.Cron,
         crontab: [
           {"* * * * *", Oban.Workers.CronA},
           {"0 * * * *", Oban.Workers.CronA, args: %{special: true}},
           {"0 0 * * *", Oban.Workers.CronB, priority: 3}
         ]}
      ]
    )

    {:ok, live, _html} = live(build_conn(), "/oban/crons")

    {:ok, live: live}
  end

  test "viewing actively running crons", %{live: live} do
    refresh(live)

    table =
      live
      |> element("#crons-table")
      |> render()

    assert table =~ ~r/cron-Oban-Workers-CronA/
    assert table =~ ~r/cron-Oban-Workers-CronB/
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
