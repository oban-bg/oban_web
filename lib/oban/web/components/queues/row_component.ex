defmodule Oban.Web.Queues.RowComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Timing

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~L"""
    <tr id="queue-<%= @queue.id %>" class="bg-white dark:bg-gray-900 hover:bg-blue-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25">
      <td class="p-3 flex">
        <button class="block pr-2 text-gray-400 hover:text-blue-500">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
        </button>

        <span rel="name"><%= @queue.queue %></span>
      </td>

      <td rel="nodes" class="py-3 pl-3 text-right tabular"><%= MapSet.size(@queue.nodes) %></td>
      <td rel="executing" class="py-3 pl-3 text-right tabular"><%= integer_to_estimate(@queue.executing) %></td>
      <td rel="available" class="py-3 pl-3 text-right tabular"><%= integer_to_estimate(@queue.available) %></td>
      <td rel="completed" class="py-3 pl-3 text-right tabular"><%= integer_to_estimate(@queue.completed) %></td>
      <td rel="local" class="py-3 pl-3 text-right tabular"><%= local_limit(@queue.local_limits) %></td>
      <td rel="global" class="py-3 pl-3 text-right tabular"><%= total_limit(@queue.global_limits, @queue.local_limits) %></td>
      <td rel="rate" class="py-3 pl-3 text-right tabular"><%= rate_limit(@queue.rate_limits) %></td>
      <td rel="uptime" class="py-3 pl-3 text-right tabular"><%= Timing.to_words(@queue.uptime) %></td>

      <td class="py-3 pr-3 flex justify-end">
        <%= if can?(:pause_queues, @access) do %>
          <button class="block pr-2 <%= if any_paused?(@queue.pauses) do %>text-yellow-400<% else %>text-gray-400<% end %> hover:text-blue-500" title="Pause or resume queue" phx-click="play_pause" phx-target="<%= @myself %>">
            <%= if any_paused?(@queue.pauses) do %>
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <% else %>
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <% end %>
          </button>
        <% end %>

        <%= if can?(:scale_queues, @access) do %>
          <button class="block text-gray-400 hover:text-blue-500">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"></path></svg>
          </button>
        <% end %>
      </td>
    </tr>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("play_pause", _params, socket) do
    if can?(:pause_queues, socket.assigns.access) do
      action = if any_paused?(socket.assigns.queue.pauses), do: :resume_queue, else: :pause_queue

      send(self(), {action, socket.assigns.queue.queue})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Helpers

  defp local_limit(limits) do
    case Enum.min_max(limits) do
      {min, min} -> min
      {min, max} -> "#{min}..#{max}"
    end
  end

  defp total_limit([global | _], _limits) when is_integer(global), do: global
  defp total_limit([_head | tail], limits), do: total_limit(limits, tail)
  defp total_limit([], limits), do: Enum.sum(limits)

  defp rate_limit([]), do: "-"
  defp rate_limit([nil | _]), do: "-"

  defp rate_limit([rate | _tail] = rates) when is_map(rate) do
    %{"allowed" => allowed, "period" => period, "window_time" => time} = rate

    curr_time = Time.truncate(Time.utc_now(), :second)

    prev_total = for %{"prev_count" => cnt} <- rates, reduce: 0, do: (acc -> acc + cnt)
    curr_total = for %{"curr_count" => cnt} <- rates, reduce: 0, do: (acc -> acc + cnt)

    ellapsed =
      time
      |> Time.from_iso8601!()
      |> Time.diff(curr_time, :second)
      |> abs()

    remaining = (prev_total * div(period - ellapsed, period) + curr_total)

    period_in_words = Timing.to_words(period, relative: false)

    "#{remaining}/#{allowed} per #{period_in_words}"
  end

  defp any_paused?(pauses), do: Enum.any?(pauses)
end
