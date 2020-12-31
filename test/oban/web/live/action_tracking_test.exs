defmodule Oban.Web.Live.ActionTrackingTest do
  use Oban.Web.DataCase

  import Phoenix.LiveViewTest

  alias Oban.Web.Plugins.Stats

  @name Oban

  setup do
    start_supervised_oban!(plugins: [Stats])

    {:ok, live, _html} = live(build_conn(), "/oban")

    {:ok, live: live}
  end

  test "tracking queue actions", context do
    handle_event = fn event, _measure, meta, pid -> send(pid, {event, meta}) end

    :telemetry.attach("web-test", [:oban_web, :action, :stop], handle_event, self())

    insert_beat!(node: "web.1", queue: "alpha")
    insert_job!([ref: 1], queue: "alpha", worker: AlphaWorker)

    refresh(context)

    click_state(context.live, "available")
    pause_queue(context.live, "alpha")

    assert_receive {[:oban_web, :action, :stop], %{action: :pause_queue}}
  after
    :telemetry.detach("web-test")
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #states #state-#{state}")
    |> render_click()

    render(live)
  end

  defp pause_queue(live, queue) do
    live
    |> element("#sidebar #queues #queue-#{queue} [phx-click='play_pause']")
    |> render_click()

    render(live)
  end

  defp refresh(%{live: live}) do
    @name
    |> Oban.Registry.whereis({:plugin, Stats})
    |> send(:refresh)

    Process.sleep(10)

    send(live.pid, :refresh)
  end
end
