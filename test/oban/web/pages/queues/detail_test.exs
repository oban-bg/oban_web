defmodule Oban.Web.Pages.Queues.DetailTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  setup [:start_supervised_oban!, :attach_signals, :stub_routing]

  test "viewing details for an inoperative queue" do
    {:error, {:live_redirect, %{to: "/oban/queues"}}} = live(build_conn(), "/oban/queues/omicron")
  end

  test "viewing details for a queue with a slash in the name" do
    gossip(local_limit: 5, queue: "foo/bar.baz")

    live = render_details("foo/bar.baz")

    assert has_element?(live, "[name=local_limit][value=\"5\"]")
  end

  test "linking each state count to the jobs filtered by queue and state" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    assert has_element?(
             live,
             ~s(#queue-state-executing[href*="queues=alpha"][href*="state=executing"])
           )

    assert has_element?(live, ~s(#queue-state-discarded[href*="state=discarded"]), "discarded")
    assert has_element?(live, "#queue-limits dd.tabular", "5")
  end

  test "scaling the local limit across all nodes" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    assert has_element?(live, "[name=local_limit][value=\"5\"]")

    live
    |> form("#local-form")
    |> render_submit(%{local_limit: 10})

    assert_action(:scale_queue, queue: "alpha")
    assert_notice(live, "Local limit set for alpha queue")
    assert_signal(%{"action" => "scale", "limit" => 10, "queue" => "alpha"})
  end

  test "showing a new limit as pending until the node reports it" do
    gossip(local_limit: 5, node: "web-1", queue: "alpha")

    live = render_details("alpha")

    refute has_element?(live, "#web-1-pending")

    live
    |> form("#local-form")
    |> render_submit(%{local_limit: 10})

    assert has_element?(live, "#web-1-pending", "10")
    refute has_element?(live, "#web-1-limit [phx-mounted]")

    gossip(local_limit: 10, node: "web-1", queue: "alpha")
    send(live.pid, :refresh)

    refute has_element?(live, "#web-1-pending")
    assert has_element?(live, "#web-1-limit [phx-mounted]", "10")
  end

  test "rejecting an invalid local limit for all nodes" do
    gossip(local_limit: 5, queue: "alpha")

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

  test "rejecting an invalid limit for a single instance" do
    gossip(local_limit: 5, queue: "alpha", node: "web-1")

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

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "rejecting invalid global and rate limits" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    live
    |> element("#toggle-global")
    |> render_click()

    live
    |> form("#global-form")
    |> render_submit(%{global_allowed: "-1"})

    assert has_element?(live, "#global-form-error[role=alert]")
    assert has_element?(live, ~s([name=global_allowed][aria-invalid="true"]))

    live
    |> element("#toggle-rate-limit")
    |> render_click()

    live
    |> form("#rate-limit-form")
    |> render_submit(%{rate_allowed: "5", rate_period: "abc"})

    assert has_element?(live, "#rate-limit-form-error[role=alert]")
    assert has_element?(live, ~s([name=rate_period][aria-invalid="true"]))
    refute has_element?(live, ~s([name=rate_allowed][aria-invalid="true"]))
    refute_receive {:action, %{action: :scale_queue}}
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "exposing names and disclosure state to assistive technology" do
    gossip(local_limit: 5, node: "web-1", queue: "alpha")

    live = render_details("alpha")

    assert has_element?(live, ~s(#instances-toggle[aria-expanded="true"][aria-controls]))
    assert has_element?(live, ~s(#config-toggle[aria-expanded="false"][aria-controls]))
    assert has_element?(live, ~s(#toggle-global[role="switch"][aria-label="Global limit"]))

    assert has_element?(
             live,
             ~s(#toggle-burst[aria-label="Burst"][aria-describedby="burst-hint"])
           )

    assert has_element?(live, ~s(#web-1-toggle-pause[aria-label="Pause on this node"]))
    assert has_element?(live, ~s(#sparkline-web-1[role="img"][aria-label*="web-1"]))

    live
    |> element("#config-toggle")
    |> render_click()

    assert has_element?(live, ~s(#config-toggle[aria-expanded="true"]))

    live
    |> element("#web-1-edit")
    |> render_click()

    assert has_element?(
             live,
             ~s(#web-1-form [name=local_limit][aria-label="Local limit on web-1"])
           )
  end

  test "leaving the details when the queue stops running on every node" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    Oban.Met.Examiner.purge(Oban.Registry.via(Oban, Oban.Met.Examiner), 1)

    send(live.pid, :refresh)

    assert_patch(live, "/oban/queues")
    assert_notice(live, "The alpha queue is no longer running on any node")
  end

  test "pausing and resuming the queue on every node" do
    gossip(local_limit: 5, node: "web-1", queue: "alpha")
    gossip(local_limit: 5, node: "web-2", queue: "alpha")

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

  test "pausing the queue on a single node" do
    gossip(local_limit: 5, node: "web-1", queue: "alpha")

    live = render_details("alpha")

    live
    |> element("#web-1-toggle-pause")
    |> render_click()

    assert_action(:pause_queue, queue: "alpha", node: "web-1")
    assert_notice(live, "Paused the alpha queue on web-1")
  end

  test "stopping the queue on every node" do
    gossip(local_limit: 5, node: "web-1", queue: "alpha", running: [1, 2])

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

  test "reporting a limit the engine rejects instead of crashing" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    send(live.pid, {:scale_queue, "alpha", global_limit: %{allowed: 5}})

    assert_notice(live, "Global limit not applied to alpha queue")
    refute_receive {:action, %{action: :scale_queue}}
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "setting the global limit across all nodes" do
    gossip(local_limit: 5, global_limit: nil, queue: "alpha")

    live = render_details("alpha")

    # Initially the input is disabled when the limit is nil
    assert has_element?(live, "[name=global_allowed][disabled]")

    live
    |> element("#toggle-global")
    |> render_click()

    # When the input is enabled it gets the local limit value
    assert has_element?(live, "[name=global_allowed][value=\"5\"]")

    live
    |> form("#global-form")
    |> render_submit(%{global_allowed: 10})

    assert_action(:scale_queue, queue: "alpha")
    assert_notice(live, "Global limit set for alpha queue")

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{"allowed" => 10},
      "queue" => "alpha"
    })
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "configuring global partitioning" do
    gossip(local_limit: 5, global_limit: %{allowed: 10}, queue: "alpha")

    live = render_details("alpha")

    refute has_element?(live, "[name=global_allowed][disabled]")

    live
    |> form("#global-form")
    |> render_submit(%{global_partition_fields: "worker"})

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{"allowed" => 10, "partition" => [["fields", ["worker"]]]},
      "queue" => "alpha"
    })

    live
    |> form("#global-form")
    |> render_submit(%{global_partition_fields: "args", global_partition_keys: "foo,bar"})

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{
        "allowed" => 10,
        "partition" => [["fields", ["args"]], ["keys", ["foo", "bar"]]]
      },
      "queue" => "alpha"
    })
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "configuring global partitioning with meta fields" do
    gossip(local_limit: 5, global_limit: %{allowed: 10}, queue: "alpha")

    live = render_details("alpha")

    live
    |> form("#global-form")
    |> render_submit(%{global_partition_fields: "meta", global_partition_keys: "tenant_id"})

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{
        "allowed" => 10,
        "partition" => [["fields", ["meta"]], ["keys", ["tenant_id"]]]
      },
      "queue" => "alpha"
    })

    live
    |> form("#global-form")
    |> render_submit(%{
      global_partition_fields: "meta,worker",
      global_partition_keys: "tenant_id"
    })

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{
        "allowed" => 10,
        "partition" => [["fields", ["meta", "worker"]], ["keys", ["tenant_id"]]]
      },
      "queue" => "alpha"
    })
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "enabling burst mode for partitioned global limits" do
    gossip(local_limit: 5, global_limit: %{allowed: 10}, queue: "alpha")

    live = render_details("alpha")

    live
    |> element("#toggle-burst")
    |> render_click()

    live
    |> form("#global-form")
    |> render_submit(%{global_partition_fields: "worker"})

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{
        "allowed" => 10,
        "burst" => true,
        "partition" => [["fields", ["worker"]]]
      },
      "queue" => "alpha"
    })
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "scaling global limits by node count" do
    gossip(local_limit: 5, global_limit: %{allowed: 10}, queue: "alpha")

    live = render_details("alpha")

    assert render(live) =~ "10 cluster-wide"
    assert has_element?(live, "#toggle-per-node[aria-checked=false]")

    live
    |> element("#toggle-per-node")
    |> render_click()

    assert has_element?(live, "#toggle-per-node[aria-checked=true]")

    live
    |> form("#global-form")
    |> render_submit(%{global_partition_fields: "args", global_partition_keys: "tenant_id"})

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{
        "allowed" => 10,
        "per_node" => true,
        "partition" => [["fields", ["args"]], ["keys", ["tenant_id"]]]
      },
      "queue" => "alpha"
    })
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "preserving per node scaling while changing other global limit options" do
    gossip(local_limit: 5, global_limit: %{allowed: 10, per_node: true}, queue: "alpha")

    live = render_details("alpha")

    assert render(live) =~ "10 per node"
    assert has_element?(live, "#toggle-per-node[aria-checked=true]")

    live
    |> form("#global-form")
    |> render_submit(%{global_allowed: 3})

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{"allowed" => 3, "per_node" => true},
      "queue" => "alpha"
    })

    live
    |> form("#global-form")
    |> render_submit(%{global_partition_fields: "worker"})

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{
        "allowed" => 3,
        "per_node" => true,
        "partition" => [["fields", ["worker"]]]
      },
      "queue" => "alpha"
    })
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "disabling per node scaling for a global limit" do
    gossip(local_limit: 5, global_limit: %{allowed: 10, per_node: true}, queue: "alpha")

    live = render_details("alpha")

    live
    |> element("#toggle-per-node")
    |> render_click()

    live
    |> form("#global-form")
    |> render_submit(%{})

    assert_signal(%{
      "action" => "scale",
      "global_limit" => %{"allowed" => 10},
      "queue" => "alpha"
    })
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "setting the rate limit across all nodes" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    # Initially the input is disabled when the limit is nil
    assert has_element?(live, "[name=rate_allowed][disabled]")

    live
    |> element("#toggle-rate-limit")
    |> render_click()

    assert has_element?(live, "[name=rate_allowed][value=\"5\"]")
    assert has_element?(live, "[name=rate_period][value=\"60\"]")

    live
    |> form("#rate-limit-form")
    |> render_submit(%{rate_allowed: 10, rate_period: 90})

    assert_action(:scale_queue, queue: "alpha")
    assert_notice(live, "Rate limit set for alpha queue")

    assert_signal(%{
      "action" => "scale",
      "queue" => "alpha",
      "rate_limit" => %{"allowed" => 10, "period" => 90}
    })
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engine]
  test "configuring rate limit partitioning" do
    gossip(local_limit: 5, rate_limit: %{allowed: 10, period: 1}, queue: "alpha")

    live = render_details("alpha")

    refute has_element?(live, "[name=rate_allowed][disabled]")

    live
    |> form("#rate-limit-form")
    |> render_submit(%{rate_partition_fields: "worker"})

    assert_signal(%{
      "action" => "scale",
      "rate_limit" => %{
        "allowed" => 10,
        "partition" => [["fields", ["worker"]]],
        "period" => 1
      },
      "queue" => "alpha"
    })

    live
    |> form("#rate-limit-form")
    |> render_submit(%{rate_partition_fields: "args", rate_partition_keys: "foo,bar"})

    assert_signal(%{
      "action" => "scale",
      "rate_limit" => %{
        "allowed" => 10,
        "partition" => [["fields", ["args"]], ["keys", ["foo", "bar"]]],
        "period" => 1
      },
      "queue" => "alpha"
    })
  end

  test "scaling the limit for a single instance" do
    gossip(local_limit: 5, queue: "alpha", node: "web-1")
    gossip(local_limit: 6, queue: "alpha", node: "web-2")

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

  defp attach_signals(_context) do
    :ok = Oban.Notifier.listen([:signal])

    :telemetry.attach(
      __MODULE__,
      [:oban_web, :action, :stop],
      &__MODULE__.handle_event/4,
      self()
    )

    on_exit(fn -> :telemetry.detach(__MODULE__) end)

    :ok
  end

  def handle_event([:oban_web, :action, _event], _measure, meta, pid) do
    send(pid, {:action, meta})
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
