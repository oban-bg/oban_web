defmodule Oban.Web.Queues.ChildRowComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr id={queue_id(@queue, @gossip["node"])} class="text-sm text-gray-600 dark:text-gray-400 bg-gray-50 dark:bg-black dark:bg-opacity-25">
      <td rel="node" colspan="2"class="py-3 font-medium text-right"><%= node_name(@gossip) %></td>
      <td rel="executing" class="py-3 text-right tabular"><%= length(@gossip["running"]) %></td>
      <td rel="available" class="py-3 text-right tabular"><%= available_count(@counts) %></td>
      <td rel="local" class="py-3 text-right tabular"><%= Map.get(@gossip, "local_limit", "-") %></td>
      <td rel="global" class="py-3 text-right tabular"><%= global_limit_to_words([@gossip]) %></td>
      <td rel="rate" class="py-3 text-right tabular"><%= rate_limit_to_words([@gossip]) %></td>
      <td rel="started" class="py-3 text-right tabular"><%= started_at([@gossip]) %></td>
      <td class="py-3 pr-3 flex justify-end">
        <.pause_button
          click="toggle-pause"
          disabled={not can?(:pause_queues, @access)}
          myself={@myself}
          paused={@gossip["paused"]} />
      </td>
    </tr>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-pause", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    gossip = socket.assigns.gossip
    action = if gossip["paused"], do: :resume_queue, else: :pause_queue

    send(self(), {action, socket.assigns.queue, gossip["name"], gossip["node"]})

    {:noreply, socket}
  end

  # Helpers

  defp queue_id(queue, node), do: ["queue-", queue, "-node-", String.replace(node, ".", "_")]

  defp available_count(counts) do
    counts
    |> Map.get("available", 0)
    |> integer_to_estimate()
  end
end
