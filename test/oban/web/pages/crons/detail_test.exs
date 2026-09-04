defmodule Oban.Workers.StaticDetailCron do
  use Oban.Worker

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Web.Pages.Crons.DetailTest do
  use Oban.Web.Case

  alias Oban.Web.Utils
  alias Oban.Workers.StaticDetailCron

  setup do
    start_supervised_oban!(plugins: [{Oban.Cron, crontab: [{"*/15 * * * *", StaticDetailCron}]}])

    name = Utils.cron_entry_name({"*/15 * * * *", StaticDetailCron, []})

    {:ok, live, _html} = live(build_conn(), "/oban/crons/#{URI.encode_www_form(name)}")

    {:ok, live: live, name: name}
  end

  test "describing a static cron's schedule", %{live: live} do
    html = refresh(live)

    assert html =~ "Every 15 minutes"
    assert html =~ "*/15 * * * *"
    assert html =~ "Oban.Workers.StaticDetailCron"

    assert has_element?(live, "h2 #back-link")
    refute has_element?(live, "#status-dynamic")
  end

  test "running a static cron immediately", %{live: live, name: name} do
    refresh(live)

    live
    |> element("button", "Run Now")
    |> render_click()

    assert [job] = Repo.all(Job)

    assert "Oban.Workers.StaticDetailCron" == job.worker
    assert %{"cron_expr" => "*/15 * * * *", "cron_name" => ^name} = job.meta
  end

  test "disabling controls that only apply to dynamic crons", %{live: live} do
    refresh(live)

    assert has_element?(live, "button[disabled]", "Pause")
    assert has_element?(live, "button[disabled]", "Delete")
    assert has_element?(live, "#cron-form-fields[disabled]")
    refute has_element?(live, "#detail-save")
  end

  defp refresh(live) do
    send(live.pid, :refresh)

    render(live)
  end
end
