defmodule Oban.Web.QueuesComponent do
  use Oban.Web, :live_component

  def render(assigns) do
    queues = [
      %{name: "alpha", nodes: 2, local: 5, total: 10, uptime: "10 minutes"},
      %{name: "gamma", nodes: 1, local: 5, total: 10, uptime: "8 minutes"},
      %{name: "delta", nodes: 1, local: 5, total: 5, uptime: "12 minutes"}
    ]

    ~L"""
    <div id="queues-page" class="w-full flex flex-col my-6 md:flex-row">
      <div id="sidebar" class="mr-0 mb-3 md:mr-3 md:mb-0">
        <div id="nodes" class="bg-white dark:bg-gray-900 w-fill mb-3 rounded-md shadow-lg overflow-hidden md:w-84">
          <header class="group flex justify-between items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
            <span class="dark:text-gray-200 font-bold">Queues</span>

            <div class="group-hover:hidden">
              <span class="text-xs text-gray-500 uppercase inline-block text-right w-10">Limit</span>
            </div>

            <div class="hidden group-hover:block">
              <button class="block w-5 h-5 text-gray-400 dark:text-gray-600 hover:text-blue-500" title="Minimize or maximize" phx-click="toggle" phx-value-menu="nodes" phx-target="<%= @myself %>">
                <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
              </button>
            </div>
          </header>
        </div>
      </div>

      <div class="flex-1 bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
        <div id="queues-header" class="flex items-center">
          <h2 class="text-lg font-bold ml-2">Queues</h2>
          <h3 class="text-lg ml-1 text-gray-500 font-normal tabular">(10)</h3>
        </div>

        <div class="flex justify-between border-b border-gray-200 dark:border-gray-700 px-3 py-3">
          <span class="text-xs text-gray-400 pl-8 uppercase">Name</span>
          <span class="text-xs text-gray-400 pl-8 uppercase">Nodes</span>
          <span class="text-xs text-gray-400 pl-8 uppercase">Limit</span>
          <span class="text-xs text-gray-400 pl-8 uppercase">Uptime</span>
        </div>

        <ul>
          <%= for queue <- queues do %>
            <li id="queue-<%= queue.name %>" class="group flex justify-between bg-white dark:bg-gray-900 border-b border-gray-100 dark:border-gray-800 hover:bg-blue-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25"><%= queue.name %></li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  def handle_refresh(socket) do
    socket
  end

  def handle_params(_, _uri, socket) do
    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end
end
