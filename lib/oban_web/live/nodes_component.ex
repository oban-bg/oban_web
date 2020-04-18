defmodule ObanWeb.NodesComponent do
  use ObanWeb.Web, :live_component

  def render(assigns) do
    ~L"""
    <div class="bg-white w-64 rounded shadow-md overflow-hidden">
      <header class="flex justify-between items-center border-b border-gray-200 px-4 py-3">
        <span class="font-bold">Nodes</span>
        <span class="text-xs text-gray-600 uppercase">Running</span>
      </header>

      <ul>
        <%= for {node, %{count: count, limit: limit}} <- @stats do %>
          <li class="text-sm flex justify-between px-4 py-3 border-l-2 border-transparent <%= if node == @filters.node do %>border-blue-400<% end %>"
              phx-click="filter"
              phx-target="<%= @myself %>"
              phx-value-node="<%= node %>">
            <span class="font-semibold cursor-pointer"><%= truncate(node, 0..30) %></span>
            <span class="text-gray-600"><%= integer_to_delimited(count) %> / <%= integer_to_delimited(limit) %></span>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  def handle_event("filter", %{"node" => node}, socket) do
    send(self(), {:filter_node, node})

    {:noreply, socket}
  end
end
