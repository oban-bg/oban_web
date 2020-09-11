defmodule Oban.Web.Live.IsolationTest do
  use Oban.Web.DataCase

  import Phoenix.LiveViewTest

  @oban_opts [
    repo: Repo,
    name: ObanPrivate,
    prefix: "private",
    crontab: false,
    queues: false,
    plugins: [Oban.Web.Plugins.Stats]
  ]

  setup do
    start_supervised!({Oban, @oban_opts})

    {:ok, live, _html} = live(build_conn(), "/oban-private")

    {:ok, live: live}
  end

  test "viewing available jobs for a custom oban supervisor", context do
    job_1 = Job.new(%{}, worker: AlphaWorker)
    job_2 = Job.new(%{}, worker: DeltaWorker)
    job_3 = Job.new(%{}, worker: GammaWorker)

    Oban.insert_all(ObanPrivate, [job_1, job_2, job_3])

    html = click_state(context.live, "available")

    assert html =~ "AlphaWorker"
    assert html =~ "DeltaWorker"
    assert html =~ "GammaWorker"
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #states #state-#{state}")
    |> render_click()

    render(live)
  end
end
