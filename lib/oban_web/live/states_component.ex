defmodule ObanWeb.StatesComponent do
  use ObanWeb.Web, :live_component

  def render(assigns) do
    ~L"""
    <div class="bg-white w-84 mb-6 rounded shadow-md overflow-hidden">
      <header class="flex justify-between items-center border-b border-gray-200 px-4 py-3">
        <span class="font-bold">States</span>
        <span class="text-xs text-gray-600 uppercase">Count</span>
      </header>

      <ul class="py-2">
        <%= for {state, %{count: count}} <- @stats do %>
          <li class="text-sm flex justify-between cursor-pointer px-4 py-2 border-l-2 border-transparent hover:bg-blue-50 <%= if state == @filters.state do %>border-blue-400<% end %>"
              phx-click="filter"
              phx-target="<%= @myself %>"
              phx-value-state="<%= state %>">
            <span class="font-semibold"><%= state %></span>
            <span class="text-gray-500 inline-block text-right w-10"><%= integer_to_delimited(count) %></span>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  def handle_event("filter", %{"state" => state}, socket) do
    send(self(), {:filter_state, state})

    {:noreply, socket}
  end
end
