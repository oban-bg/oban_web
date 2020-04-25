defmodule ObanWeb.SidebarComponent do
  use ObanWeb.Web, :live_component

  alias ObanWeb.{NodeComponent, QueueComponent, StateComponent}

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
      <ul>
        <%= for {name, stat} <- @node_stats do %>
          <%= live_component @socket, NodeComponent, id: name, filters: @filters, name: name, stat: stat %>
        <% end %>
      </ul>
    </div>

    <div class="bg-white w-84 mb-6 rounded shadow-md overflow-hidden">
      <header class="flex justify-between items-center border-b border-gray-200 px-4 py-3">
        <span class="font-bold">States</span>
        <div>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Count</span>
        </div>
      </header>
      <ul>
        <%= for {name, stat} <- @state_stats do %>
          <%= live_component @socket, StateComponent, id: name, filters: @filters, name: name, stat: stat %>
        <% end %>
      </ul>
    </div>

    <div class="bg-white w-84 mb-6 rounded shadow-md overflow-hidden">
      <header class="flex justify-between items-center border-b border-gray-200 px-4 py-3">
        <span class="font-bold">Queues</span>
        <div>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Exec</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Limit</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Avail</span>
        </div>
      </header>
      <ul>
        <%= for {name, stat} <- @queue_stats do %>
          <%= live_component @socket, QueueComponent, id: name, filters: @filters, name: name, stat: stat %>
        <% end %>
      </ul>
    """
  end
end
