defmodule Oban.Web.Queues.GroupRowComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.Timing

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr id={"queue-#{@queue}"} class="bg-white dark:bg-gray-900 hover:bg-blue-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25">
      <td class="p-3 dark:text-gray-300">
        <button rel="expand"
          title={"Expand #{@queue} to view details by node"}
          class="block flex items-center hover:text-blue-500 focus:outline-none focus:text-blue-500"
          phx-click="toggle_queue"
          phx-target={@myself}>
          <%= if @expanded do %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
          <% else %>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
          <% end %>

          <span class="pl-1 font-semibold" rel="name"><%= @queue %></span>
        </button>
      </td>

      <td rel="nodes" class="py-3 pl-3 text-right text-gray-400 tabular"><%= nodes_count(@gossip) %></td>
      <td rel="executing" class="py-3 pl-3 text-right text-gray-400 tabular"><%= executing_count(@gossip) %></td>
      <td rel="available" class="py-3 pl-3 text-right text-gray-400 tabular"><%= available_count(@counts) %></td>
      <td rel="local" class="py-3 pl-3 text-right text-gray-400 tabular"><%= local_limit(@gossip) %></td>
      <td rel="global" class="py-3 pl-3 text-right text-gray-400 tabular"><%= global_limit(@gossip) %></td>
      <td rel="rate" class="py-3 pl-3 text-right text-gray-400 tabular"><%= rate_limit(@gossip) %></td>
      <td rel="started" class="py-3 pl-3 text-right text-gray-400 tabular"><%= started_at(@gossip) %></td>

      <td class="py-3 pr-3 flex justify-end">
        <%= if can?(:pause_queues, @access) do %>
          <button rel="play_pause"
            class={"block pr-2 #{pause_color(@gossip)} hover:text-blue-500"}
            title="Pause or resume queue"
            phx-click="play_pause"
            phx-target={@myself}
            phx-throttle="1000">
            <%= if any_paused?(@gossip) do %>
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <% else %>
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <% end %>
          </button>
        <% end %>

        <%= live_patch to: oban_path(@socket, :queues, %{id: @queue}), class: "block text-gray-400 hover:text-blue-500" do %>
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"></path></svg>
        <% end %>
      </td>
    </tr>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("play_pause", _params, socket) do
    if can?(:pause_queues, socket.assigns.access) do
      action = if any_paused?(socket.assigns.gossip), do: :resume_queue, else: :pause_queue

      send(self(), {action, socket.assigns.queue})
    end

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
      true -> "text-gray-400"
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

  defp global_limit(gossip) do
    Enum.find_value(gossip, "-", & &1["global_limit"])
  end

  defp rate_limit(gossip) do
    gossip
    |> Enum.map(& &1["rate_limit"])
    |> Enum.reject(&is_nil/1)
    |> case do
      [head_limit | _rest] = rate_limits ->
        %{"allowed" => allowed, "period" => period, "window_time" => time} = head_limit

        {prev_total, curr_total} =
          rate_limits
          |> Enum.flat_map(& &1["windows"])
          |> Enum.reduce({0, 0}, fn %{"prev_count" => pcnt, "curr_count" => ccnt}, {pacc, cacc} ->
            {pacc + pcnt, cacc + ccnt}
          end)

        curr_time = Time.truncate(Time.utc_now(), :second)

        ellapsed =
          time
          |> Time.from_iso8601!()
          |> Time.diff(curr_time, :second)
          |> abs()

        remaining = prev_total * div(period - ellapsed, period) + curr_total

        period_in_words = Timing.to_words(period, relative: false)

        "#{remaining}/#{allowed} per #{period_in_words}"

      [] ->
        "-"
    end
  end

  defp any_paused?(gossip), do: Enum.any?(gossip, & &1["paused"])
end
