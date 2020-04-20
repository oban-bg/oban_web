defmodule ObanWeb.NodesComponent do
  use ObanWeb.Web, :live_component

  def render(assigns) do
    ~L"""
    <div class="bg-white w-84 mb-6 rounded shadow-md overflow-hidden">
      <header class="flex justify-between items-center border-b border-gray-200 px-4 py-3">
        <span class="font-bold">Nodes</span>
        <div>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Exec</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Limit</span>
        </div>
      </header>

      <ul class="py-2">
        <%= for {node, %{count: execu, limit: limit}} <- @stats do %>
          <li class="text-sm flex justify-between cursor-pointer px-4 py-2 border-l-2 border-transparent hover:bg-blue-50 <%= if node == @filters.node do %>border-blue-400<% end %>"
              phx-click="filter"
              phx-target="<%= @myself %>"
              phx-value-node="<%= node %>">
            <span class="font-semibold"><%= truncate(node, 0..30) %></span>
            <div>
              <span class="text-gray-500 inline-block text-right w-12 tabular"><%= integer_to_delimited(execu) %></span>
              <span class="text-gray-500 inline-block text-right w-12 tabular"><%= integer_to_delimited(limit) %></span>
            </div>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  def handle_event("filter", %{"node" => node}, socket) do
    new_node = if node == socket.assigns.filters.node, do: "any", else: node

    send(self(), {:filter_node, new_node})

    {:noreply, socket}
  end
end
