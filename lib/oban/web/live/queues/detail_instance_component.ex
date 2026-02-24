defmodule Oban.Web.Queues.DetailInstanceComponent do
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
      |> assign(node_history: assigns[:node_history] || [])
      |> assign(queue: assigns.checks["queue"])
      |> assign(paused: assigns.checks["paused"])
      |> assign_new(:local_limit, fn -> assigns.checks["local_limit"] end)
      |> assign_new(:editing?, fn -> false end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr class={if @editing?, do: "bg-gray-50 dark:bg-gray-800"}>
      <td class="pl-3 py-3">
        <div class="flex items-center space-x-2">
          <span class="truncate">{node_name(@checks)}</span>
          <.status_indicators checks={@checks} paused={@paused} />
        </div>
      </td>
      <%= if @editing? do %>
        <td colspan="5" class="pr-3 py-3">
          <form
            id={"#{@checks["node"]}-form"}
            class="flex items-center justify-end"
            phx-target={@myself}
            phx-submit="update"
          >
            <input type="hidden" name="node" value={@checks["node"]} />

            <div class="flex items-center space-x-4">
              <div class="w-24">
                <input
                  type="number"
                  name="local_limit"
                  value={@local_limit}
                  disabled={not can?(:scale_queues, @access)}
                  class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50"
                />
              </div>

              <div class="flex space-x-2">
                <button
                  type="button"
                  class="px-3 py-2 text-sm font-medium text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 rounded-md cursor-pointer"
                  phx-click="cancel-edit"
                  phx-target={@myself}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class={"px-3 py-2 text-sm font-medium text-white bg-blue-500 hover:bg-blue-600 rounded-md cursor-pointer #{if @local_limit == @checks["local_limit"], do: "opacity-50 cursor-not-allowed"}"}
                  disabled={@local_limit == @checks["local_limit"]}
                >
                  Scale
                </button>
              </div>
            </div>
          </form>
        </td>
      <% else %>
        <td class="py-3">
          <Core.sparkline
            id={"sparkline-#{@checks["node"]}"}
            history={if is_map(@node_history), do: @node_history, else: %{}}
            count={120}
          />
        </td>
        <td class="text-right py-3 tabular">{executing_count(@checks)}</td>
        <td class="text-right py-3 tabular">{@checks["local_limit"]}</td>
        <td class="text-right py-3">{started_at(@checks)}</td>
        <td class="pr-3 py-3">
          <div class="flex items-center justify-end space-x-2">
            <.pause_button
              disabled={not can?(:pause_queues, @access)}
              node={node_name(@checks)}
              paused={@paused}
              queue={@queue}
              target={@myself}
            />
            <.edit_button
              disabled={not can?(:scale_queues, @access)}
              node={@checks["node"]}
              target={@myself}
            />
          </div>
        </td>
      <% end %>
    </tr>
    """
  end

  defp status_indicators(assigns) do
    terminating? = not is_nil(assigns.checks["shutdown_started_at"])
    assigns = assign(assigns, terminating?: terminating?)

    ~H"""
    <span
      :if={@terminating?}
      class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-red-100 text-red-700 dark:bg-red-900/50 dark:text-red-300"
    >
      <Icons.power class="w-3 h-3 mr-0.5" /> Stopping
    </span>
    <span
      :if={@paused and not @terminating?}
      class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-700 dark:bg-yellow-900/50 dark:text-yellow-300"
    >
      <Icons.pause_circle class="w-3 h-3 mr-0.5" /> Paused
    </span>
    """
  end

  defp pause_button(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> "#{assigns.node}-toggle-pause" end)
      |> assign_new(:tooltip, fn -> if assigns.paused, do: "Resume queue", else: "Pause queue" end)

    ~H"""
    <button
      id={@id}
      rel="toggle-pause"
      class="p-1.5 rounded text-gray-400 dark:text-gray-500 hover:text-yellow-500 dark:hover:text-yellow-500 hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
      data-title={@tooltip}
      disabled={@disabled}
      phx-click="toggle-pause"
      phx-hook="Tippy"
      phx-target={@target}
      phx-value-queue={@queue}
      phx-value-node={@node}
      type="button"
    >
      <%= if @paused do %>
        <Icons.play_circle class="w-5 h-5" />
      <% else %>
        <Icons.pause_circle class="w-5 h-5" />
      <% end %>
    </button>
    """
  end

  defp edit_button(assigns) do
    ~H"""
    <button
      id={"#{@node}-edit"}
      rel="toggle-edit"
      class="p-1.5 rounded text-gray-400 dark:text-gray-500 hover:text-violet-500 dark:hover:text-violet-500 hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
      data-title="Edit local limit"
      disabled={@disabled}
      phx-click="toggle-edit"
      phx-hook="Tippy"
      phx-target={@target}
      type="button"
    >
      <Icons.pencil_square class="w-5 h-5" />
    </button>
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

  def handle_event("toggle-edit", _params, socket) do
    {:noreply, assign(socket, editing?: not socket.assigns.editing?)}
  end

  def handle_event("cancel-edit", _params, socket) do
    {:noreply, assign(socket, editing?: false, local_limit: socket.assigns.checks["local_limit"])}
  end

  def handle_event("update", %{"local_limit" => limit}, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    limit = String.to_integer(limit)
    checks = socket.assigns.checks

    send(self(), {:scale_queue, checks["queue"], checks["name"], checks["node"], limit})

    {:noreply, assign(socket, local_limit: limit, editing?: false)}
  end
end
