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
      {"0 0 * * *", StaticCronB, priority: 3}
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

    for mode <- ~w(worker last_run next_run schedule) do
      live
      |> element("a#sort-#{mode}")
      |> render_click()

      assert_patch(
        live,
        "/oban/crons?#{URI.encode_query(limit: 20, sort_by: mode, sort_dir: "asc")}"
      )
    end
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
