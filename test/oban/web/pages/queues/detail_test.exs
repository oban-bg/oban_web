defmodule Oban.Web.Pages.Queues.DetailTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  setup [:start_supervised_oban!, :attach_signals]

  test "viewing details for an inoperative queue" do
    {:error, {:live_redirect, %{to: "/oban/queues"}}} = live(build_conn(), "/oban/queues/omicron")
  end

  test "scaling the local limit across all nodes" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    assert has_element?(live, "[name=local_limit][value=5]")

    live
    |> form("#local-form")
    |> render_submit(%{local_limit: 10})

    assert_action(:scale_queue, queue: "alpha")
    assert_notice(live, "Local limit set for alpha queue")
    assert_signal(%{"action" => "scale", "limit" => 10, "queue" => "alpha"})
  end

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engines.Smart]
  test "setting the global limit across all nodes" do
    gossip(local_limit: 5, global_limit: nil, queue: "alpha")

    live = render_details("alpha")

    # Initially the input is disabled when the limit is nil
    assert has_element?(live, "[name=global_allowed][disabled]")

    live
    |> element("#toggle-global")
    |> render_click()

    # When the input is enabled it gets the local limit value
    assert has_element?(live, "[name=global_allowed][value=5]")

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

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engines.Smart]
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

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engines.Smart]
  test "setting the rate limit across all nodes" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    # Initially the input is disabled when the limit is nil
    assert has_element?(live, "[name=rate_allowed][disabled]")

    live
    |> element("#toggle-rate-limit")
    |> render_click()

    assert has_element?(live, "[name=rate_allowed][value=5]")
    assert has_element?(live, "[name=rate_period][value=60]")

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

  @tag pro: true, oban_opts: [engine: Oban.Pro.Engines.Smart]
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

    assert has_element?(live, "#local-form [name=local_limit][value=6]")
    assert has_element?(live, "#web-1-form [name=local_limit][value=5]")
    assert has_element?(live, "#web-2-form [name=local_limit][value=6]")

    live
    |> form("#web-1-form")
    |> render_submit(%{local_limit: 9})

    assert_action(:scale_queue, queue: "alpha", node: "web-1")
    assert_notice(live, "Local limit set for alpha queue on web-1")

    assert has_element?(live, "#local-form [name=local_limit][value=9]")
    assert has_element?(live, "#web-1-form [name=local_limit][value=9]")
    assert has_element?(live, "#web-2-form [name=local_limit][value=6]")

    live
    |> form("#web-1-form")
    |> render_submit(%{local_limit: 4})

    assert has_element?(live, "#local-form [name=local_limit][value=6]")
    assert has_element?(live, "#web-1-form [name=local_limit][value=4]")
    assert has_element?(live, "#web-2-form [name=local_limit][value=6]")
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

  defp render_details(queue) do
    {:ok, live, _html} = live(build_conn(), "/oban/queues/#{queue}")

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
