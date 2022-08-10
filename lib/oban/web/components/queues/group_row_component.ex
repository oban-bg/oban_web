defmodule Oban.Web.Queues.GroupRowComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr id={"queue-#{@queue}"} class="bg-white dark:bg-gray-900 hover:bg-blue-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25">
      <td class="pl-3 py-3 text-gray-700 dark:text-gray-300 flex items-center space-x-2">
        <button rel="expand"
          class="block hover:text-blue-500 focus:outline-none focus:text-blue-500"
          data-title={"Expand #{@queue} to view instances"}
          id={"expand-#{@queue}"}
          type="button"
          phx-click="toggle_queue"
          phx-target={@myself}
          phx-hook="Tippy">
          <%= if @expanded do %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
          <% else %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
          <% end %>
        </button>

        <%= live_patch @queue,
            to: oban_path(:queues, %{id: @queue}),
            "aria-label": "View and configure #{@queue} details",
            class: "block font-semibold text-gray-700 dark:text-gray-300 hover:text-blue-500 dark:hover:text-blue-500",
            rel: "name" %>
      </td>

      <td rel="nodes" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular"><%= nodes_count(@gossip) %></td>
      <td rel="executing" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular"><%= executing_count(@gossip) %></td>
      <td rel="available" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular"><%= available_count(@counts) %></td>
      <td rel="local" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular"><%= local_limit(@gossip) %></td>
      <td rel="global" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular"><%= global_limit_to_words(@gossip) %></td>
      <td rel="rate" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular"><%= rate_limit_to_words(@gossip) %></td>
      <td rel="started" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular"><%= started_at(@gossip) %></td>

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
          phx-hook="Tippy">
          <%= if any_paused?(@gossip) do %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
          <% else %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
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
