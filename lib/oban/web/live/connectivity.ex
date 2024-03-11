defmodule Oban.Web.Live.Connectivity do
  use Oban.Web, :live_component

  alias Oban.Notifier

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    status = Notifier.status(assigns.conf)

    title =
      case status do
        :isolated -> "Node is isolated, updates disabled"
        :solitary -> "Node is solitary, not in a cluster"
        _ -> ""
      end

    socket =
      socket
      |> assign(conf: assigns.conf, id: assigns.id)
      |> assign(status: status, title: title)

    if connected?(socket) do
      send_update_after(__MODULE__, %{socket.assigns | status: :reset}, :timer.seconds(15))
    end

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="connectivity" data-title={@title} phx-hook="Tippy">
      <Icons.bolt_circle :if={@status == :solitary} class="w-6 h-6 text-orange-500" />
      <Icons.bolt_slash :if={@status == :isolated} class="w-6 h-6 animate-pulse text-red-500" />
    </div>
    """
  end
end
