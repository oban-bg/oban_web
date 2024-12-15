defmodule Oban.Web.Queues.GroupRowComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.Components.Core

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <tr
      id={"queue-#{@queue}"}
      class="bg-white dark:bg-gray-900 hover:bg-gray-50 dark:hover:bg-gray-950/30"
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

        <.link
          patch={oban_path([:queues, @queue])}
          title={"View and configure #{@queue} details"}
          class="block font-semibold text-gray-700 dark:text-gray-300 hover:text-blue-500 dark:hover:text-blue-500"
          rel="name"
        >
          {@queue}
        </.link>
      </td>

      <td rel="nodes" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        {nodes_count(@checks)}
      </td>
      <td rel="executing" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        {executing_count(@checks)}
      </td>
      <td rel="available" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        {integer_to_estimate(@counts)}
      </td>
      <td rel="local" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        {local_limit(@checks)}
      </td>
      <td rel="global" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        {global_limit_to_words(@checks)}
      </td>
      <td rel="rate" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        {rate_limit_to_words(@checks)}
      </td>
      <td rel="started" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        {started_at(@checks)}
      </td>

      <td class="py-3 pr-5 flex justify-end border-r border-transparent">
        <Core.pause_button
          click="toggle-pause"
          disabled={not can?(:pause_queues, @access)}
          id={"#{@queue}-toggle-pause"}
          myself={@myself}
          paused={any_paused?(@checks)}
          title={pause_title(@checks)}
        />
      </td>
    </tr>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-pause", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    action = if any_paused?(socket.assigns.checks), do: :resume_queue, else: :pause_queue

    send(self(), {action, socket.assigns.queue})

    {:noreply, socket}
  end

  def handle_event("toggle_queue", _, socket) do
    send(self(), {:toggle_queue, socket.assigns.queue})

    {:noreply, socket}
  end

  # Helpers

  defp pause_title(checks) do
    cond do
      Enum.all?(checks, & &1["paused"]) -> "Resume all instances"
      Enum.any?(checks, & &1["paused"]) -> "Resume paused instances"
      true -> "Pause all instances"
    end
  end

  defp nodes_count(checks), do: length(checks)

  defp local_limit(checks) do
    checks
    |> Enum.map(& &1["local_limit"])
    |> Enum.min_max()
    |> case do
      {min, min} -> min
      {min, max} -> "#{min}..#{max}"
    end
  end

  defp any_paused?(checks), do: Enum.any?(checks, & &1["paused"])
end
