defmodule Oban.Web.Queues.DetailInsanceComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.Components.Core

  @impl Phoenix.LiveComponent
  def update(%{local_limit: local_limit}, socket) do
    {:ok, assign(socket, local_limit: local_limit)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(access: assigns.access, checks: assigns.checks)
      |> assign_new(:paused, fn -> assigns.checks["paused"] end)
      |> assign_new(:local_limit, fn -> assigns.checks["local_limit"] end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr>
      <td class="pl-3 py-3">{node_name(@checks)}</td>
      <td class="text-right py-3">{executing_count(@checks)}</td>
      <td class="text-right py-3">{started_at(@checks)}</td>
      <td class="pl-9 py-3">
        <Core.pause_button
          click="toggle-pause"
          disabled={not can?(:pause_queues, @access)}
          myself={@myself}
          paused={@paused}
        />
      </td>
      <td class="pr-3 py-3">
        <form
          id={"#{@checks["node"]}-form"}
          class="flex space-x-3"
          phx-target={@myself}
          phx-submit="update"
        >
          <input type="hidden" name="node" value={@checks["node"]} />

          <Core.number_input
            label={false}
            name="local_limit"
            value={@local_limit}
            disabled={not can?(:scale_queues, @access)}
            myself={@myself}
          />

          <button
            class={"block px-3 py-2 font-medium text-sm text-gray-600 dark:text-gray-100 bg-gray-300 dark:bg-blue-300 dark:bg-opacity-25 hover:bg-blue-500 hover:text-white dark:hover:bg-blue-500 dark:hover:text-white rounded-md shadow-sm #{if @local_limit == @checks["local_limit"], do: "opacity-30 pointer-events-none"}"}
            type="submit"
          >
            Scale
          </button>
        </form>
      </td>
    </tr>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-pause", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    checks = socket.assigns.checks
    action = if socket.assigns.paused, do: :resume_queue, else: :pause_queue

    send(self(), {action, checks["queue"], checks["name"], checks["node"]})

    {:noreply, assign(socket, paused: not socket.assigns.paused)}
  end

  def handle_event("update", %{"local_limit" => limit}, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    limit = String.to_integer(limit)
    checks = socket.assigns.checks

    send(self(), {:scale_queue, checks["queue"], checks["name"], checks["node"], limit})

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
