defmodule Oban.Workers.DetailCronWorker do
  use Oban.Worker

  @impl true
  def perform(_job), do: :ok
end

defmodule Oban.Web.Pages.Crons.DetailTest do
  use Oban.Web.Case

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

      assert live
             |> refresh()
             |> render() =~ "America/Chicago"

      {:ok, live, _html} = live(build_conn(), "/oban/crons/without-tz")

      assert live
             |> refresh()
             |> render() =~ "Etc/UTC"
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

      assert live
             |> refresh()
             |> render() =~ "Completed"
    end

    test "displays schedule expression" do
      DynamicCron.insert([{"*/15 * * * *", DetailCronWorker, name: "schedule-test"}])

      {:ok, live, _html} = live(build_conn(), "/oban/crons/schedule-test")
      refresh(live)

      html = render(live)
      assert html =~ "*/15 * * * *"
    end
  end

  defp refresh(live) do
    send(live.pid, :refresh)

    live
  end
end
