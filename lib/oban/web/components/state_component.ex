defmodule Oban.Web.StateComponent do
  use Oban.Web, :live_component

  def update(assigns, socket) do
    {:ok,
     assign(
       socket,
       name: assigns.name,
       active?: assigns.name == assigns.filters.state,
       count: assigns.stat.count
     )}
  end

  def render(assigns) do
    ~L"""
    <li id="state-<%= @name %>" class="text-sm" phx-click="filter" phx-target="<%= @myself %>">
      <div class="flex justify-between cursor-pointer px-3 py-3 border-l-2 border-transparent hover:bg-gray-50 <%= if @active? do %>border-blue-400<% end %>">
        <span class="font-semibold"><%= @name %></span>
        <span class="text-gray-500 text-right tabular"><%= integer_to_delimited(@count) %></span>
      </div>
    </li>
    """
  end

  def handle_event("filter", _params, socket) do
    send(self(), {:filter_state, socket.assigns.name})

    {:noreply, socket}
  end
end
