defmodule Oban.Web.Pages.Queues.DetailTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  setup do
    start_supervised_oban!()

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

  test "viewing details for an inoperative queue" do
    {:error, {:live_redirect, %{to: "/oban/queues"}}} = live(build_conn(), "/oban/queues/omicron")
  end

  test "scaling the local limit across all nodes" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    assert has_element?(live, "#local_limit[value=5]")

    live
    |> form("#local-form")
    |> render_submit(%{local_limit: 10})

    assert_action(:scale_queue, queue: "alpha")
    assert_notice(live, "Local limit set for alpha queue")
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
    assert_notice(live, "Global limit set for alpha queue")

    assert_signal(%{"action" => "scale", "global_limit" => %{"allowed" => 10}, "queue" => "alpha"})
  end

  test "setting the rate limit across all nodes" do
    gossip(local_limit: 5, queue: "alpha")

    live = render_details("alpha")

    # Initially the input is disabled when the limit is nil
    assert has_element?(live, "#rate_limit_allowed[disabled]")

    live
    |> element("#toggle-rate-limit")
    |> render_click()

    assert has_element?(live, "#rate_limit_allowed[value=5]")
    assert has_element?(live, "#rate_limit_period[value=60]")

    live
    |> form("#rate-limit-form")
    |> render_submit(%{rate_limit_allowed: 10, rate_limit_period: 90})

    assert_action(:scale_queue, queue: "alpha")
    assert_notice(live, "Rate limit set for alpha queue")

    assert_signal(%{
      "action" => "scale",
      "queue" => "alpha",
      "rate_limit" => %{"allowed" => "10", "period" => "90"}
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
