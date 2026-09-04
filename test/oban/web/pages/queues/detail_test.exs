defmodule Oban.Web.Pages.Queues.DetailTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  setup [:start_supervised_oban!, :attach_signals, :stub_routing]

  test "viewing details for an inoperative queue" do
    {:error, {:live_redirect, %{to: "/oban/queues"}}} = live(build_conn(), "/oban/queues/omicron")
  end

  test "viewing details for a queue with a slash in the name", %{oban: oban} do
    gossip(oban, local_limit: 5, queue: "foo/bar.baz")

    live = render_details("foo/bar.baz")

    assert has_element?(live, "[name=local_limit][value=\"5\"]")
  end

  test "linking each state count to the jobs filtered by queue and state", %{oban: oban} do
    gossip(oban, local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    assert has_element?(
             live,
             ~s(#queue-state-executing[href*="queues=alpha"][href*="state=executing"])
           )

    assert has_element?(live, ~s(#queue-state-discarded[href*="state=discarded"]), "discarded")
    assert has_element?(live, "#queue-limits dd.tabular", "5")
  end

  test "scaling the local limit across all nodes", %{oban: oban} do
    gossip(oban, local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    assert has_element?(live, "[name=local_limit][value=\"5\"]")

    live
    |> form("#local-form")
    |> render_submit(%{local_limit: 10})

    assert_action(:scale_queue, queue: "alpha")
    assert_notice(live, "Local limit set for alpha queue")
    assert_signal(%{"action" => "scale", "limit" => 10, "queue" => "alpha"})
  end

  test "showing a new limit as pending until the node reports it", %{oban: oban} do
    gossip(oban, local_limit: 5, node: "web-1", queue: "alpha")

    live = render_details("alpha")

    refute has_element?(live, "#web-1-pending")

    live
    |> form("#local-form")
    |> render_submit(%{local_limit: 10})

    assert has_element?(live, "#web-1-pending", "10")
    refute has_element?(live, "#web-1-limit [phx-mounted]")

    gossip(oban, local_limit: 10, node: "web-1", queue: "alpha")
    send(live.pid, :refresh)

    refute has_element?(live, "#web-1-pending")
    assert has_element?(live, "#web-1-limit [phx-mounted]", "10")
  end

  test "rejecting an invalid local limit for all nodes", %{oban: oban} do
    gossip(oban, local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    live
    |> form("#local-form")
    |> render_submit(%{local_limit: "0"})

    assert has_element?(live, "#local-form-error[role=alert]", "whole number of 1 or more")
    assert has_element?(live, ~s(#local_limit[aria-invalid="true"]))
    refute_receive {:action, %{action: :scale_queue}}

    live
    |> form("#local-form")
    |> render_submit(%{local_limit: "3"})

    refute has_element?(live, "#local-form-error")
    assert_signal(%{"action" => "scale", "limit" => 3, "queue" => "alpha"})
  end

  test "rejecting an invalid limit for a single instance", %{oban: oban} do
    gossip(oban, local_limit: 5, queue: "alpha", node: "web-1")

    live = render_details("alpha")

    live
    |> element("#web-1-edit")
    |> render_click()

    live
    |> form("#web-1-form")
    |> render_submit(%{local_limit: " "})

    assert has_element?(live, "#web-1-error[role=alert]", "whole number of 1 or more")
    assert has_element?(live, "#web-1-form [name=local_limit]")
    refute_receive {:action, %{action: :scale_queue}}
  end

  test "leaving the details when the queue stops running on every node", %{oban: oban} do
    gossip(oban, local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    Oban.Met.Examiner.purge(Oban.Registry.via(oban, Oban.Met.Examiner), 1)

    send(live.pid, :refresh)

    assert_patch(live, "/oban/queues")
    assert_notice(live, "The alpha queue is no longer running on any node")
  end

  test "pausing and resuming the queue on every node", %{oban: oban} do
    gossip(oban, local_limit: 5, node: "web-1", queue: "alpha")
    gossip(oban, local_limit: 5, node: "web-2", queue: "alpha")

    live = render_details("alpha")

    live
    |> element("#detail-pause-resume")
    |> render_click()

    assert_action(:pause_queue, queue: "alpha")
    assert_notice(live, "Paused the alpha queue on 2 nodes")
    assert has_element?(live, "#status-paused")

    live
    |> element("#detail-pause-resume")
    |> render_click()

    assert_action(:resume_queue, queue: "alpha")
    assert_notice(live, "Resumed the alpha queue on 2 nodes")
    refute has_element?(live, "#status-paused")
  end

  test "pausing the queue on a single node", %{oban: oban} do
    gossip(oban, local_limit: 5, node: "web-1", queue: "alpha")

    live = render_details("alpha")

    live
    |> element("#web-1-toggle-pause")
    |> render_click()

    assert_action(:pause_queue, queue: "alpha", node: "web-1")
    assert_notice(live, "Paused the alpha queue on web-1")
  end

  test "stopping the queue on every node", %{oban: oban} do
    gossip(oban, local_limit: 5, node: "web-1", queue: "alpha", running: [1, 2])

    live = render_details("alpha")

    assert has_element?(
             live,
             ~s(#detail-stop[data-confirm*="Stop the alpha queue on 1 node? 2 executing jobs"])
           )

    live
    |> element("#detail-stop")
    |> render_click()

    assert_action(:stop_queue, queue: "alpha")
    assert_notice(live, "Stopped the alpha queue on 1 node")
  end

  test "reporting a limit the engine rejects instead of crashing", %{oban: oban} do
    gossip(oban, local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    send(live.pid, {:scale_queue, "alpha", global_limit: %{allowed: 5}})

    assert_notice(live, "Global limit not applied to alpha queue")
    refute_receive {:action, %{action: :scale_queue}}
  end

  test "scaling the limit for a single instance", %{oban: oban} do
    gossip(oban, local_limit: 5, queue: "alpha", node: "web-1")
    gossip(oban, local_limit: 6, queue: "alpha", node: "web-2")

    live = render_details("alpha")

    assert has_element?(live, "#local-form [name=local_limit][value=\"6\"]")

    # Click edit button to enter edit mode for web-1
    live
    |> element("#web-1-edit")
    |> render_click()

    assert has_element?(live, "#web-1-form [name=local_limit][value=\"5\"]")
    assert has_element?(live, "#web-1-form button[type=submit][disabled]")

    live
    |> form("#web-1-form")
    |> render_change(%{local_limit: 9})

    refute has_element?(live, "#web-1-form button[type=submit][disabled]")

    live
    |> form("#web-1-form")
    |> render_submit(%{local_limit: 9})

    assert_action(:scale_queue, queue: "alpha", node: "web-1")
    assert_notice(live, "Local limit set for alpha queue on web-1")

    assert has_element?(live, "#local-form [name=local_limit][value=\"9\"]")

    # Click edit again for web-1 to change the limit
    live
    |> element("#web-1-edit")
    |> render_click()

    live
    |> form("#web-1-form")
    |> render_submit(%{local_limit: 4})

    assert has_element?(live, "#local-form [name=local_limit][value=\"6\"]")
  end

  # Helpers

  defp attach_signals(%{oban: oban}) do
    :ok = Oban.Notifier.listen(oban, [:signal])

    handler_id = {__MODULE__, oban}

    :telemetry.attach(
      handler_id,
      [:oban_web, :action, :stop],
      &__MODULE__.handle_event/4,
      {self(), oban}
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    :ok
  end

  # Actions from concurrently running tests fire the same event, only forward our instance's.
  def handle_event([:oban_web, :action, _event], _measure, meta, {pid, oban}) do
    case meta do
      %{config: %{name: ^oban}} -> send(pid, {:action, meta})
      _ -> :ok
    end
  end

  defp stub_routing(_context) do
    socket = %Phoenix.LiveView.Socket{endpoint: Oban.Web.Endpoint, router: Oban.Web.Test.Router}
    Process.put(:routing, {socket, "/oban"})

    :ok
  end

  defp render_details(queue) do
    {:ok, live, _html} = live(build_conn(), Oban.Web.Helpers.oban_path([:queues, queue]))

    live
  end

  defp assert_action(action, expected) do
    assert_receive {:action, %{action: ^action} = message}

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
