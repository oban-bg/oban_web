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
        _ -> "Connected to cluster"
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
    <div
      id="connectivity"
      aria-live="polite"
      role="status"
      class="flex h-9 items-center"
      data-title={@title}
      phx-hook="Tippy"
    >
      <span class="sr-only">{@title}</span>

      <%= case @status do %>
        <% :solitary -> %>
          <.degraded icon="icon-bolt-circle" label="Solitary" color="yellow" />
        <% :isolated -> %>
          <.degraded icon="icon-bolt-slash" label="Isolated" color="red" pulse />
        <% :disconnected -> %>
          <.degraded icon="icon-exclamation-circle" label="Disconnected" color="red" pulse />
        <% _connected -> %>
          <span class="block w-2 h-2 rounded-full bg-emerald-400" aria-hidden="true"></span>
      <% end %>
    </div>
    """
  end

  attr :color, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :pulse, :boolean, default: false

  defp degraded(assigns) do
    class =
      case assigns.color do
        "yellow" -> "text-yellow-600 dark:text-yellow-400"
        "red" -> "text-red-600 dark:text-red-400"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <span class={["flex items-center gap-1.5", @class]} aria-hidden="true">
      <Icons.icon name={@icon} class={["w-5 h-5", if(@pulse, do: "animate-pulse")]} />
      <span class="text-sm font-medium">{@label}</span>
    </span>
    """
  end
end
