defmodule Oban.Web.NodeComponent do
  use Oban.Web, :live_component

  def update(assigns, socket) do
    {:ok,
     assign(
       socket,
       name: assigns.name,
       active?: assigns.name == assigns.filters.node,
       count: assigns.stat.count,
       limit: assigns.stat.limit
     )}
  end

  def render(assigns) do
    ~L"""
    <li id="node-<%= @name %>" class="text-sm cursor-pointer outline-none" tabindex="0" phx-click="filter" phx-target="<%= @myself %>">
      <div class="flex justify-between px-3 py-3 border-l-2 border-transparent hover:bg-gray-50 <%= if @active? do %>border-blue-400<% end %>">
        <span class="flex-initial font-semibold truncate"><%= String.downcase(@name) %></span>
        <div class="flex-none">
          <span class="text-gray-500 inline-block text-right w-10 tabular"><%= integer_to_delimited(@count) %></span>
          <span class="text-gray-500 inline-block text-right w-10 tabular"><%= integer_to_delimited(@limit) %></span>
        </div>
      </div>
    </li>
    """
  end

  def handle_event("filter", _params, socket) do
    new_node = if socket.assigns.active?, do: "any", else: socket.assigns.name

    send(self(), {:filter_node, new_node})

    {:noreply, socket}
  end
end
