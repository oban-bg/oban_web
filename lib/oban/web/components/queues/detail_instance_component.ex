defmodule Oban.Web.Queues.DetailInsanceComponent do
  use Oban.Web, :live_component

  import Oban.Web.Components.FormComponent
  import Oban.Web.Helpers.QueueHelper

  @impl Phoenix.LiveComponent
  def update(%{local_limit: local_limit}, socket) do
    {:ok, assign(socket, local_limit: local_limit)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(access: assigns.access, gossip: assigns.gossip)
      |> assign_new(:paused, fn -> assigns.gossip["paused"] end)
      |> assign_new(:local_limit, fn -> assigns.gossip["local_limit"] end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr>
      <td class="pl-3 py-3"><%= node_name(@gossip) %></td>
      <td class="text-right py-3"><%= executing_count(@gossip) %></td>
      <td class="text-right py-3"><%= started_at(@gossip) %></td>
      <td class="pl-6 py-3">
        <button rel="play_pause"
          class="block text-gray-500 hover:text-blue-500"
          title="Pause or resume queue"
          phx-click="toggle-pause"
          phx-target={@myself}
          phx-throttle="5000">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
        </button>
      </td>
      <td class="pr-3 py-3">
        <form id={"#{@gossip["node"]}-form"} class="flex space-x-3" phx-target={@myself} phx-submit="update">
          <input type="hidden" name="node" value={@gossip["node"]} />

          <.number_input
            label={false}
            name="local_limit"
            value={@local_limit}
            disabled={not can?(:scale_queues, @access)}
            myself={@myself} />

          <button class="block px-3 py-2 font-medium text-sm text-gray-600 dark:text-gray-100 bg-gray-300 dark:bg-blue-300 dark:bg-opacity-25 hover:bg-blue-500 hover:text-white dark:hover:bg-blue-500 dark:hover:text-white rounded-md shadow-sm">Scale</button>
        </form>
      </td>
    </tr>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-pause", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("update", %{"local_limit" => limit}, socket) do
    limit = String.to_integer(limit)
    gossip = socket.assigns.gossip

    send(self(), {:scale_queue, gossip["queue"], gossip["name"], gossip["node"], limit})

    {:noreply, assign(socket, local_limit: limit)}
  end

  def handle_event("increment", _params, socket) do
    {:noreply, assign(socket, local_limit: socket.assigns.local_limit + 1)}
  end

  def handle_event("decrement", _params, socket) do
    if socket.assigns.local_limit > 1 do
      {:noreply, assign(socket, local_limit: socket.assigns.local_limit - 1)}
    else
      {:noreply, socket}
    end
  end
end
