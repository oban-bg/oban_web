defmodule Oban.Web.Queues.ChildRowComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.Timing

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr id={queue_id(@queue, @gossip["node"])} class="text-gray-400 bg-gray-100 dark:bg-black dark:bg-opacity-25">
      <td rel="node" colspan="2"class="py-3 text-right"><%= node_name(@gossip) %></td>
      <td rel="executing" class="py-3 text-right tabular"><%= length(@gossip["running"]) %></td>
      <td rel="available" class="py-3 text-right tabular"><%= available_count(@counts) %></td>
      <td rel="local" class="py-3 text-right tabular"><%= Map.get(@gossip, "local_limit", "-") %></td>
      <td rel="global" class="py-3 text-right tabular"><%= Map.get(@gossip, "global_limit", "-") %></td>
      <td rel="rate" class="py-3 text-right tabular"><%= rate_limit([@gossip]) %></td>
      <td rel="started" class="py-3 text-right tabular"><%= started_at([@gossip]) %></td>
      <td class="py-3 pr-10 flex justify-end">
        <%= if can?(:pause_queues, @access) do %>
          <button rel="play_pause" class={"block hover:text-blue-500 #{if @gossip["paused"], do: "text-red-500", else: "text-gray-500"}"}
            title="Pause or resume queue"
            phx-click="play_pause"
            phx-target={@myself}
            phx-throttle="1000">
            <%= if @gossip["paused"] do %>
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <% else %>
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
            <% end %>
          </button>
        <% end %>
      </td>
    </tr>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("play_pause", _params, socket) do
    if can?(:pause_queues, socket.assigns.access) do
      gossip = socket.assigns.gossip
      action = if gossip["paused"], do: :resume_queue, else: :pause_queue

      send(self(), {action, socket.assigns.queue, gossip["name"], gossip["node"]})
    end

    {:noreply, socket}
  end

  # Helpers

  defp queue_id(queue, node), do: ["queue-", queue, "-node-", String.replace(node, ".", "_")]

  defp available_count(counts) do
    counts
    |> Map.get("available", 0)
    |> integer_to_estimate()
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
end
