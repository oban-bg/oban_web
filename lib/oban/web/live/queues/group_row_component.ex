defmodule Oban.Web.Queues.GroupRowComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr
      id={"queue-#{@queue}"}
      class="bg-white dark:bg-gray-900 hover:bg-blue-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25"
    >
      <td class="pl-3 py-3 text-gray-700 dark:text-gray-300 flex items-center space-x-2">
        <button
          rel="expand"
          class="block hover:text-blue-500 focus:outline-none focus:text-blue-500"
          data-title={"Expand #{@queue} to view instances"}
          id={"expand-#{@queue}"}
          type="button"
          phx-click="toggle_queue"
          phx-target={@myself}
          phx-hook="Tippy"
        >
          <%= if @expanded do %>
            <Icons.chevron_down class="w-5 h-5" />
          <% else %>
            <Icons.chevron_right class="w-5 h-5" />
          <% end %>
        </button>

        <%= live_patch(@queue,
          to: oban_path([:queues, @queue]),
          "aria-label": "View and configure #{@queue} details",
          class:
            "block font-semibold text-gray-700 dark:text-gray-300 hover:text-blue-500 dark:hover:text-blue-500",
          rel: "name"
        ) %>
      </td>

      <td rel="nodes" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= nodes_count(@gossip) %>
      </td>
      <td rel="executing" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= executing_count(@gossip) %>
      </td>
      <td rel="available" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= available_count(@counts) %>
      </td>
      <td rel="local" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= local_limit(@gossip) %>
      </td>
      <td rel="global" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= global_limit_to_words(@gossip) %>
      </td>
      <td rel="rate" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= rate_limit_to_words(@gossip) %>
      </td>
      <td rel="started" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= started_at(@gossip) %>
      </td>

      <td class="py-3 pr-3 flex justify-end">
        <button
          rel="toggle-pause"
          class={"block #{pause_color(@gossip)} hover:text-blue-500"}
          disabled={not can?(:pause_queues, @access)}
          data-title={pause_title(@gossip)}
          id={"#{@queue}-toggle-pause"}
          type="button"
          phx-click="toggle-pause"
          phx-target={@myself}
          phx-throttle="2000"
          phx-hook="Tippy"
        >
          <%= if any_paused?(@gossip) do %>
            <Icons.play_circle class="w-5 h-5" />
          <% else %>
            <Icons.pause_circle class="w-5 h-5" />
          <% end %>
        </button>
      </td>
    </tr>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-pause", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    action = if any_paused?(socket.assigns.gossip), do: :resume_queue, else: :pause_queue

    send(self(), {action, socket.assigns.queue})

    {:noreply, socket}
  end

  def handle_event("toggle_queue", _, socket) do
    send(self(), {:toggle_queue, socket.assigns.queue})

    {:noreply, socket}
  end

  # Helpers

  defp pause_color(gossip) do
    cond do
      Enum.all?(gossip, & &1["paused"]) -> "text-red-500"
      Enum.any?(gossip, & &1["paused"]) -> "text-yellow-400"
      true -> "text-gray-600 dark:text-gray-400"
    end
  end

  defp pause_title(gossip) do
    cond do
      Enum.all?(gossip, & &1["paused"]) -> "Resume all instances"
      Enum.any?(gossip, & &1["paused"]) -> "Resume paused instances"
      true -> "Pause all instances"
    end
  end

  defp nodes_count(gossip), do: length(gossip)

  defp available_count(counts) do
    counts
    |> Map.get("available", 0)
    |> integer_to_estimate()
  end

  defp local_limit(gossip) do
    gossip
    |> Enum.map(& &1["local_limit"])
    |> Enum.min_max()
    |> case do
      {min, min} -> min
      {min, max} -> "#{min}..#{max}"
    end
  end

  defp any_paused?(gossip), do: Enum.any?(gossip, & &1["paused"])
end
