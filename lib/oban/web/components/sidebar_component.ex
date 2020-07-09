defmodule Oban.Web.SidebarComponent do
  use Oban.Web, :live_component

  alias Oban.Web.{NodeComponent, QueueComponent, StateComponent}

  def mount(socket) do
    {:ok, assign(socket, show_nodes?: true, show_states?: true, show_queues?: true)}
  end

  def render(assigns) do
    ~L"""
    <div id="nodes" class="bg-white w-fill mb-3 rounded-md shadow-md overflow-hidden md:w-84">
      <header class="group flex justify-between items-center border-b border-gray-200 px-3 py-3">
        <span class="font-bold">Nodes</span>

        <div class="group-hover:hidden">
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Exec</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Limit</span>
        </div>

        <div class="hidden group-hover:block">
          <button class="block w-5 h-5 text-gray-400 hover:text-blue-500" title="Minimize or maximize" phx-click="toggle" phx-value-menu="nodes" phx-target="<%= @myself %>">
            <%= if @show_nodes? do %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% else %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% end %>
          </button>
        </div>
      </header>

      <ul class="<%= if @show_nodes? do %>block<% else %>hidden<% end %>">
        <%= for {name, stat} <- @node_stats do %>
          <%= live_component @socket, NodeComponent, id: name, filters: @filters, name: name, stat: stat %>
        <% end %>
      </ul>
    </div>

    <div id="states" class="bg-white w-full mb-3 rounded-md shadow-md overflow-hidden md:w-84">
      <header class="group flex justify-between items-center border-b border-gray-200 px-3 py-3">
        <span class="font-bold">States</span>

        <div class="group-hover:hidden">
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Count</span>
        </div>

        <div class="hidden group-hover:block">
          <button class="block w-5 h-5 text-gray-400 hover:text-blue-500" title="Minimize or maximize" phx-click="toggle" phx-value-menu="states" phx-target="<%= @myself %>">
            <%= if @show_states? do %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% else %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% end %>
          </button>
        </div>
      </header>

      <ul class="<%= if @show_states? do %>block<% else %>hidden<% end %>">
        <%= for {name, stat} <- @state_stats do %>
          <%= live_component @socket, StateComponent, id: name, filters: @filters, name: name, stat: stat %>
        <% end %>
      </ul>
    </div>

    <div id="queues" class="bg-white w-full rounded-md shadow-md overflow-hidden md:w-84">
      <header class="group flex justify-between items-center border-b border-gray-200 px-3 py-3">
        <span class="font-bold">Queues</span>

        <div class="group-hover:hidden">
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Exec</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Limit</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-12">Avail</span>
        </div>

        <div class="hidden group-hover:block">
          <button class="block w-5 h-5 text-gray-400 hover:text-blue-500" title="Minimize or maximize" phx-click="toggle" phx-value-menu="queues" phx-target="<%= @myself %>">
            <%= if @show_queues? do %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% else %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% end %>
          </button>
        </div>
      </header>

      <ul class="<%= if @show_queues? do %>block<% else %>hidden<% end %>">
        <%= for {name, stat} <- @queue_stats do %>
          <%= live_component @socket, QueueComponent, id: name, filters: @filters, name: name, stat: stat %>
        <% end %>
      </ul>
    """
  end

  def handle_event("toggle", %{"menu" => "nodes"}, socket) do
    {:noreply, assign(socket, show_nodes?: not socket.assigns.show_nodes?)}
  end

  def handle_event("toggle", %{"menu" => "states"}, socket) do
    {:noreply, assign(socket, show_states?: not socket.assigns.show_states?)}
  end

  def handle_event("toggle", %{"menu" => "queues"}, socket) do
    {:noreply, assign(socket, show_queues?: not socket.assigns.show_queues?)}
  end
end
