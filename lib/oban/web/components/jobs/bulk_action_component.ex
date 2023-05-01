defmodule Oban.Web.Jobs.BulkActionComponent do
  use Oban.Web, :live_component

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

  def render(assigns) do
    expanded_class =
      if assigns.expanded?, do: "h-12 py-3 bg-gray-100 dark:bg-gray-800", else: "h-0"

    assigns = assign(assigns, expanded_class: expanded_class)

    ~H"""
    <div
      id="bulk-action"
      class={"flex items-center bg-white dark:bg-gray-900 shadow-inner overflow-hidden transition-all duration-300 ease-in-out px-3 #{@expanded_class}"}
    >
      <span class="text-sm font-semibold text-blue-500"><%= @count %> Jobs Selected</span>

      <%= if can?(:cancel_jobs, @access) and @cancelable? do %>
        <a
          id="bulk-cancel"
          href="#"
          class="group flex items-center ml-4 text-sm text-gray-500 hover:text-blue-500"
          phx-target={@myself}
          phx-click="cancel"
        >
          <Icons.x_circle class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" /> Cancel
        </a>
      <% end %>

      <%= if can?(:retry_jobs, @access) and @runnable? do %>
        <a
          id="bulk-retry"
          href="#"
          class="group flex items-center ml-4 text-sm text-gray-500 hover:text-blue-500"
          phx-target={@myself}
          phx-click="retry"
        >
          <Icons.arrow_right_circle class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" />
          Run Now
        </a>
      <% end %>

      <%= if can?(:retry_jobs, @access) and @retryable? do %>
        <a
          id="bulk-retry"
          href="#"
          class="group flex items-center ml-4 text-sm text-gray-500 hover:text-blue-500"
          phx-target={@myself}
          phx-click="retry"
        >
          <Icons.arrow_path class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" /> Retry
        </a>
      <% end %>

      <%= if can?(:delete_jobs, @access) and @deletable? do %>
        <a
          id="bulk-delete"
          href="#"
          class="group flex items-center ml-4 text-sm text-gray-500 hover:text-blue-500"
          phx-target={@myself}
          phx-click="delete"
        >
          <Icons.trash class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" /> Delete
        </a>
      <% end %>
    </div>
    """
  end

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
