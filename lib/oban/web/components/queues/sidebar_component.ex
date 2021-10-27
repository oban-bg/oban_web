defmodule Oban.Web.Queues.SidebarComponent do
  use Oban.Web, :live_component

  alias Phoenix.LiveView.JS

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="sidebar" class="mr-0 mb-3 md:mr-3 md:mb-0">
      <div id="nodes" class="bg-white dark:bg-gray-900 w-fill mb-3 rounded-md shadow-lg overflow-hidden md:w-84">
        <header class="group flex justify-between items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
          <span class="dark:text-gray-200 font-bold">Nodes</span>

          <div class="group-hover:hidden">
            <span class="text-xs text-gray-500 uppercase inline-block text-right w-10">Exec</span>
            <span class="text-xs text-gray-500 uppercase inline-block text-right w-10">Limit</span>
          </div>

          <div class="hidden group-hover:block">
            <button class="block w-5 h-5 text-gray-400 dark:text-gray-600 hover:text-blue-500" title="Minimize or maximize" phx-click={toggle_rows("node")}>
              <svg id="node-hide-icon" class="block" fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
              <svg id="node-show-icon" class="hidden" fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            </button>
          </div>
        </header>

        <div id="node-rows" class="divide-y divide-gray-200 dark:divide-gray-700">
          <%= for node <- @nodes do %>
            <.node_row node={node} active={@active} socket={@socket} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp node_row(assigns) do
    active_class = if assigns.active == assigns.node.name, do: "border-blue-500"

    ~H"""
    <%= live_patch(
        to: filter_link(@socket, @node.name, @active),
        id: "node-#{@node.name}",
        rel: "filter",
        class: "flex justify-between py-3 border-l-4 border-transparent hover:bg-gray-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25 #{active_class}") do %>
      <span class="pl-2 text-sm dark:text-gray-300 text-left font-semibold truncate">
        <%= String.downcase(@node.name) %>
      </span>
      <div class="flex-none">
        <span class="pr-3 text-sm text-gray-400 text-right tabular"><%= integer_to_estimate(@node.count) %></span>
        <span class="pr-3 text-sm text-gray-400 text-right tabular"><%= integer_to_estimate(@node.limit) %></span>
      </div>
    <% end %>
    """
  end

  defp filter_link(socket, node, node), do: oban_path(socket, :queues)
  defp filter_link(socket, node, _ative), do: oban_path(socket, :queues, node: node)

  defp toggle_rows(prefix) do
    JS.toggle(to: "##{prefix}-hide-icon")
    |> JS.toggle(to: "##{prefix}-show-icon")
    |> JS.toggle(to: "##{prefix}-rows")
  end
end
