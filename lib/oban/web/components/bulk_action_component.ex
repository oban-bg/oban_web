defmodule Oban.Web.BulkActionComponent do
  use Oban.Web, :live_component

  def mount(socket) do
    {:ok,
     assign(socket,
       count: 0,
       access: :read,
       cancelable?: false,
       deletable?: false,
       expanded?: false,
       runnable?: false,
       retryable?: false
     )}
  end

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
    ~L"""
    <div class="flex items-center bg-white shadow-inner overflow-hidden transition-all duration-300 ease-in-out px-3 <%= if @expanded? do %>h-12 py-3 bg-gray-100<% else %>h-0<% end %>">
      <span class="text-sm font-semibold text-blue-500"><%= @count %> Jobs Selected</span>

      <%= if can?(:cancel_jobs, @access) and @cancelable? do %>
        <a href="#"
           class="group flex items-center ml-4 text-sm text-gray-500 hover:bg-gray-100 hover:text-blue-500"
           phx-target="<%= @myself %>" phx-click="cancel">
          <svg class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
          Cancel
        </a>
      <% end %>

      <%= if can?(:retry_jobs, @access) and @runnable? do %>
        <a href="#"
           class="group flex items-center ml-4 text-sm text-gray-500 hover:bg-gray-100 hover:text-blue-500"
           phx-target="<%= @myself %>" phx-click="retry">
          <svg class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
          Run Now
        </a>
      <% end %>

      <%= if can?(:retry_jobs, @access) and @retryable? do %>
        <a href="#"
           class="group flex items-center ml-4 text-sm text-gray-500 hover:bg-gray-100 hover:text-blue-500"
           phx-target="<%= @myself %>" phx-click="retry">
          <svg class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
          Retry
        </a>
      <% end %>

      <%= if can?(:delete_jobs, @access) and @deletable? do %>
        <a href="#"
           class="group flex items-center ml-4 text-sm text-gray-500 hover:bg-gray-100 hover:text-blue-500"
           phx-target="<%= @myself %>" phx-click="delete">
          <svg class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
          Delete
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
