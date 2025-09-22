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
    start_supervised_oban!(plugins: [{Oban.Plugins.Cron, crontab: [
      {"* * * * *", Oban.Workers.CronA},
      {"0 * * * *", Oban.Workers.CronA, args: %{special: true}},
      {"0 0 * * *", Oban.Workers.CronB, priority: 3},
    ]}])

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

  defp refresh(live) do
    send(live.pid, :refresh)
  end
end
