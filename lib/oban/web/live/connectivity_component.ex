defmodule Oban.Web.ConnectivityComponent do
  use Oban.Web, :live_component

  alias Oban.{Met, Notifier}

  @refresh :timer.seconds(15)

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    checks = Met.checks(assigns.conf.name)

    status =
      assigns.conf.name
      |> Notifier.status()
      |> determine_status(checks)

    title =
      case status do
        :isolated -> "Node is isolated: Updates are disabled"
        :solitary -> "Node is solitary: Not connected to any cluster"
        :disconnected -> "Node is disconnected: No metrics, queues, or nodes detected"
        _ -> ""
      end

    socket =
      socket
      |> assign(conf: assigns.conf, id: assigns.id)
      |> assign(status: status, title: title)

    if connected?(socket) do
      send_update_after(__MODULE__, %{socket.assigns | status: :reset}, @refresh)
    end

    {:ok, socket}
  end

  defp determine_status(pubsub, checks) do
    cond do
      Enum.empty?(checks) -> :disconnected
      pubsub == :isolated -> :isolated
      pubsub == :solitary -> :solitary
      true -> :connected
    end
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="connectivity" data-title={@title} phx-hook="Tippy">
      <Icons.bolt_circle :if={@status == :solitary} class="w-6 h-6 text-orange-500" />
      <Icons.bolt_slash :if={@status == :isolated} class="w-6 h-6 animate-pulse text-red-500" />
      <Icons.exclamation_circle
        :if={@status == :disconnected}
        class="w-6 h-6 animate-pulse text-red-500"
      />
    </div>
    """
  end
end
