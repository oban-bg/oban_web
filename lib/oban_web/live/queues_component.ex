defmodule ObanWeb.QueuesComponent do
  use ObanWeb.Web, :live_component

  def render(assigns) do
    ~L"""
    <div class="bg-white w-84 mb-6 rounded shadow-md overflow-hidden">
      <header class="flex justify-between items-center border-b border-gray-200 px-4 py-3">
        <span class="font-bold">Queues</span>
        <div>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Exec</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Limit</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Avail</span>
        </div>
      </header>
      <ul class="py-2">
        <%= for {queue, %{avail: avail, execu: execu, limit: limit}} <- @stats do %>
          <li class="text-sm flex justify-between cursor-pointer px-4 py-2 border-l-2 border-transparent hover:bg-blue-50 <%= if queue == @filters.queue do %>border-blue-400<% end %>"
              phx-click="filter"
              phx-target="<%= @myself %>"
              phx-value-queue="<%= queue %>">
            <span class="font-semibold"><%= queue %></span>
            <div>
              <span class="text-gray-500 inline-block text-right w-12 tabular"><%= integer_to_delimited(execu) %></span>
              <span class="text-gray-500 inline-block text-right w-12 tabular"><%= integer_to_delimited(limit) %></span>
              <span class="text-gray-500 inline-block text-right w-12 tabular"><%= integer_to_delimited(avail) %></span>
            </div>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  def handle_event("filter", %{"queue" => queue}, socket) do
    new_queue = if queue == socket.assigns.filters.queue, do: "any", else: queue

    IO.inspect([queue, new_queue])

    send(self(), {:filter_queue, new_queue})

    {:noreply, socket}
  end
end
