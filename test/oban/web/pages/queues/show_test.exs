defmodule Oban.Web.Pages.Queues.IndexTest do
  use Oban.Web.DataCase

  import Phoenix.LiveViewTest

  alias Oban.Web.Plugins.Stats
  alias Oban.Pro.Queue.SmartEngine
  alias Oban.Pro.Notifiers.PG

  setup do
    start_supervised_oban!(
      engine: SmartEngine,
      notifier: PG,
      plugins: [Stats]
    )

    :ok = Oban.Notifier.listen([:signal])

    :telemetry.attach(
      __MODULE__,
      [:oban_web, :action, :stop],
      &__MODULE__.handle_event/4,
      self()
    )

    :ok
  end

  def handle_event([:oban_web, :action, _event], _measure, meta, pid) do
    send(pid, {:action, meta})
  end

  test "scaling the local limit across all nodes" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    assert has_element?(live, "#local_limit[value=5]")

    live
    |> form("#local-form")
    |> render_submit(%{local_limit: 10})

    assert_action(:scale_queue, queue: "alpha")
    assert_notice(live, "local limit set for alpha queue")
    assert_signal(%{"action" => "scale", "limit" => 10, "queue" => "alpha"})
  end

  test "setting the global limit across all nodes" do
    gossip(local_limit: 5, global_limit: nil, queue: "alpha")

    live = render_details("alpha")

    # Initially the input is disabled when the limit is nil
    assert has_element?(live, "#global_limit[disabled]")

    live
    |> element("#toggle-global")
    |> render_click()

    # When the input is enabled it gets the local limit value
    assert has_element?(live, "#global_limit[value=5]")

    live
    |> form("#global-form")
    |> render_submit(%{global_limit: 10})

    assert_action(:scale_queue, queue: "alpha")
    assert_notice(live, "global limit set for alpha queue")
    assert_signal(%{"action" => "scale", "global_limit" => 10, "queue" => "alpha"})
  end

  defp render_details(queue) do
    {:ok, live, _html} = live(build_conn(), "/oban/queues/#{queue}")

    live
  end

  defp assert_action(action, expected) do
    assert_received {:action, %{action: ^action} = message}

    for {key, val} <- expected do
      assert message[key] == val
    end
  end

  defp assert_signal(expected) do
    assert_receive {:notification, :signal, message}

    for {key, val} <- expected do
      assert message[key] == val
    end
  end

  defp assert_notice(live, message) do
    assert has_element?(live, "#notice", message)
  end
end
