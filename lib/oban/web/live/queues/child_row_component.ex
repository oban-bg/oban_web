defmodule Oban.Web.Queues.ChildRowComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.Components.Core

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr
      id={queue_id(@queue, @checks["node"])}
      class="text-sm text-gray-600 dark:text-gray-400 bg-gray-50 dark:bg-black dark:bg-opacity-25"
    >
      <td rel="node" colspan="2" class="py-3 font-medium text-right">{node_name(@checks)}</td>
      <td rel="executing" class="py-3 text-right tabular">{length(@checks["running"])}</td>
      <td rel="available" class="py-3 text-right tabular"></td>
      <td rel="local" class="py-3 text-right tabular">{Map.get(@checks, "local_limit", "-")}</td>
      <td rel="global" class="py-3 text-right tabular">{global_limit_to_words([@checks])}</td>
      <td rel="rate" class="py-3 text-right tabular">{rate_limit_to_words([@checks])}</td>
      <td rel="started" class="py-3 text-right tabular">{started_at([@checks])}</td>
      <td class="py-3 pr-5 border-r border-transparent flex justify-end">
        <Core.pause_button
          click="toggle-pause"
          disabled={not can?(:pause_queues, @access)}
          myself={@myself}
          paused={@checks["paused"]}
        />
      </td>
    </tr>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-pause", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    checks = socket.assigns.checks
    action = if checks["paused"], do: :resume_queue, else: :pause_queue

    send(self(), {action, socket.assigns.queue, checks["name"], checks["node"]})

    {:noreply, socket}
  end

  # Helpers

  defp queue_id(queue, node), do: ["queue-", queue, "-node-", String.replace(node, ".", "_")]
end
