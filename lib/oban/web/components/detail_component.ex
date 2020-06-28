defmodule Oban.Web.DetailComponent do
  use Oban.Web, :live_component

  def mount(socket) do
    {:ok, assign(socket, job: nil, hidden?: true)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, job: assigns.job, hidden?: is_nil(assigns.job))}
  end

  def render(assigns) do
    ~L"""
    <div class="fixed z-50 bottom-0 inset-0 p-0 flex items-center justify-center <%= if @hidden? do %>hidden<% end %>" role="dialog" tabindex="-1" phx-window-keydown="close" phx-target="<%= @myself %>">
      <div class="fixed inset-0" phx-click="close" phx-value-action="close" phx-target="<%= @myself %>">
        <div class="absolute inset-0 bg-gray-500 opacity-75"></div>
      </div>

      <div class="max-w-5xl bg-white rounded-md overflow-hidden shadow-xl transform transition-all sm:w-full" role="dialog">
        <%= unless @hidden? do %>
          <div class="bg-blue-50 px-5 py-5">
            <div class="flex justify-between items-center">
              <div>
                <span class="text-lg text-gray-500 tabular"><%= @job.id %></span>
                <span class="text-lg font-semibold text-blue-900 ml-1"><%= @job.worker %></span>
              </div>

              <div class="flex">
                <%= if cancelable?(@job) do %>
                  <a href="#"
                     class="group flex items-center ml-4 text-sm text-gray-500 bg-white pl-2 pr-3 py-2 border border-gray-300 rounded-md hover:text-blue-500"
                     phx-target="<%= @myself %>" phx-click="cancel">
                    <svg class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
                    Cancel
                  </a>
                <% end %>

                <%= if runnable?(@job) do %>
                  <a href="#"
                     class="group flex items-center ml-4 text-sm text-gray-500 bg-white pl-2 pr-3 py-2 border border-gray-300 rounded-md hover:text-blue-500"
                     phx-target="<%= @myself %>" phx-click="retry">
                    <svg class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
                    Run Now
                  </a>
                <% end %>

                <%= if retryable?(@job) do %>
                  <a href="#"
                     class="group flex items-center ml-4 text-sm text-gray-500 bg-white pl-2 pr-3 py-2 border border-gray-300 rounded-md hover:text-blue-500"
                     phx-target="<%= @myself %>" phx-click="retry">
                    <svg class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
                    Retry
                  </a>
                <% end %>

                <%= if deletable?(@job) do %>
                  <a href="#"
                     class="group flex items-center ml-4 text-sm text-gray-500 bg-white pl-2 pr-3 py-2 border border-gray-300 rounded-md hover:text-blue-500"
                     phx-target="<%= @myself %>" phx-click="delete">
                    <svg class="mr-1 h-5 w-5 text-gray-400 group-hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
                    Delete
                  </a>
                <% end %>
              </div>
            </div>

            <div class="text-sm flex justify-left pt-3 text-blue-900">
              <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 mr-1">Queue</span> <%= @job.queue %></div>
              <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 mr-1">Attempt</span> <%= @job.attempt %> of <%= @job.max_attempts %></div>
              <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 mr-1">Priority</span> <%= @job.priority %></div>
              <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 mr-1">Tags</span> <%= formatted_tags(@job) %></div>
              <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 mr-1">Node</span> <%= attempted_by(@job) %></div>
            </div>
          </div>

          <div class="px-5 py-4 border-t border-gray-200">
            <h3 class="font-semibold mb-3">Args</h3>
            <pre><code class="font-mono text-sm text-gray-500 overflow-x-scroll"><%= inspect(@job.args, pretty: true) %></code></pre>
          </div>

          <div class="px-5 py-4 border-t border-gray-200">
            <h3 class="font-semibold">Errors</h3>

            <%= if Enum.any?(@job.errors) do %>
              <%= for %{"at" => at, "attempt" => attempt, "error" => error} <- Enum.reverse(@job.errors) do %>
                <div class="mt-3">
                  <h4 class="text-sm mb-2">Attempt <%= attempt %> (<%= iso8601_to_words(at) %>)</h4>
                  <pre><code class="font-mono text-sm text-gray-500 overflow-x-scroll"><%= error %></code></pre>
                </div>
              <% end %>
            <% else %>
              <code class="font-mono text-sm text-gray-500">No Errors</code>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_event("close", %{"key" => "Escape"}, socket) do
    send(self(), :hide_details)

    {:noreply, socket}
  end

  def handle_event("close", %{"action" => "close"}, socket) do
    send(self(), :hide_details)

    {:noreply, socket}
  end

  def handle_event("close", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    send(self(), {:cancel_job, socket.assigns.job})

    {:noreply, socket}
  end

  def handle_event("delete", _params, socket) do
    send(self(), {:delete_job, socket.assigns.job})

    {:noreply, socket}
  end

  def handle_event("retry", _params, socket) do
    send(self(), {:retry_job, socket.assigns.job})

    {:noreply, socket}
  end
end
