defmodule Oban.Web.Queues.SidebarComponent do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~L"""
    <div id="sidebar" class="mr-0 mb-3 md:mr-3 md:mb-0">
      <table id="nodes" class="table-fixed bg-white dark:bg-gray-900 w-fill mb-3 rounded-md shadow-lg md:w-84">
        <thead class="border-b border-gray-200 dark:border-gray-700">
          <tr>
            <th scope="col" class="py-3 pl-3 dark:text-gray-200 text-left font-bold">Nodes</th>
            <th class="pr-3 text-xs font-medium text-gray-500 uppercase tracking-wider text-right w-12">Exec</th>
            <th class="pr-3 text-xs font-medium text-gray-500 uppercase tracking-wider text-right w-12">Limit</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-200 dark:divide-gray-700">
          <%= for node <- @nodes do %>
            <tr id="node-<%= @id %>" class="border-l-4 border-transparent hover:bg-gray-50 dark:hover:bg-gray-800">
              <td class="pl-2 py-3 text-sm dark:text-gray-300 text-left font-semibold truncate">
                <a href="#" class=""><%= String.downcase(node.name) %></a>
              </td>
              <td class="pr-3 py-3 text-sm text-gray-500 text-right tabular"><%= integer_to_estimate(node.count) %></td>
              <td class="pr-3 py-3 text-sm text-gray-500 text-right tabular"><%= integer_to_estimate(node.limit) %></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end
end
