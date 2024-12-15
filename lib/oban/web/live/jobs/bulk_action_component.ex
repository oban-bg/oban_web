defmodule Oban.Web.Jobs.BulkActionComponent do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {:ok,
     assign(socket,
       access: assigns.access,
       cancelable?: Enum.all?(assigns.jobs, &cancelable?/1),
       count: Enum.count(assigns.selected),
       deletable?: Enum.all?(assigns.jobs, &deletable?/1),
       expanded?: Enum.any?(assigns.selected),
       runnable?: Enum.all?(assigns.jobs, &runnable?/1),
       retryable?: Enum.all?(assigns.jobs, &retryable?/1)
     )}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id="bulk-action"
      class={"flex items-center bg-white dark:bg-gray-900 shadow-inner overflow-hidden transition-all px-3 #{expanded_class(@expanded?)}"}
    >
      <span class="text-sm font-semibold text-blue-500 tabular">{@count} Jobs Selected</span>

      <%= if can?(:cancel_jobs, @access) and @cancelable? do %>
        <button
          id="bulk-cancel"
          class="group flex items-center ml-4 text-sm text-gray-500 hover:text-blue-500"
          phx-target={@myself}
          phx-click="cancel"
          type="button"
        >
          <Icons.x_circle class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" /> Cancel Jobs
        </button>
      <% end %>

      <%= if can?(:retry_jobs, @access) and @runnable? do %>
        <button
          id="bulk-run-now"
          class="group flex items-center ml-4 text-sm text-gray-500 hover:text-blue-500"
          phx-target={@myself}
          phx-click="retry"
          type="button"
        >
          <Icons.arrow_right_circle class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" />
          Run Now
        </button>
      <% end %>

      <%= if can?(:retry_jobs, @access) and @retryable? do %>
        <button
          id="bulk-retry"
          class="group flex items-center ml-4 text-sm text-gray-500 hover:text-blue-500"
          phx-target={@myself}
          phx-click="retry"
          type="button"
        >
          <Icons.arrow_path class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" /> Retry Jobs
        </button>
      <% end %>

      <%= if can?(:delete_jobs, @access) and @deletable? do %>
        <button
          id="bulk-delete"
          class="group flex items-center ml-4 text-sm text-gray-500 hover:text-blue-500"
          phx-target={@myself}
          data-confirm="Are you sure you want to delete these jobs?"
          phx-click="delete"
          type="button"
        >
          <Icons.trash class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" /> Delete Jobs
        </button>
      <% end %>
    </div>
    """
  end

  defp expanded_class(true), do: "h-12 py-3 bg-gray-100 dark:bg-gray-800"
  defp expanded_class(_not), do: "h-0"

  @impl Phoenix.LiveComponent
  def handle_event("cancel", _params, socket) do
    if can?(:cancel_jobs, socket.assigns.access) do
      send(self(), :cancel_selected)
    end

    {:noreply, assign(socket, expanded?: false)}
  end

  def handle_event("retry", _params, socket) do
    if can?(:retry_jobs, socket.assigns.access) do
      send(self(), :retry_selected)
    end

    {:noreply, assign(socket, expanded?: false)}
  end

  def handle_event("delete", _params, socket) do
    if can?(:delete_jobs, socket.assigns.access) do
      send(self(), :delete_selected)
    end

    {:noreply, assign(socket, expanded?: false)}
  end
end
