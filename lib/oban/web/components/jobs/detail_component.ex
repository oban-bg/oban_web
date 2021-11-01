defmodule Oban.Web.Jobs.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Jobs.TimelineComponent
  alias Oban.Web.Timing

  def render(assigns) do
    ~H"""
    <div id="job-details">
      <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
        <a href="#" class="flex items-center" phx-click="close" phx-target={@myself}>
          <svg class="h-5 w-5 hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd"></path></svg>
          <span class="text-lg font-bold ml-2">Job Details</span>
        </a>

        <div class="flex">
          <%= if can?(:cancel_jobs, @access) and cancelable?(@job) do %>
            <a id="detail-cancel"
               href="#"
               class="group flex items-center ml-4 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none hover:text-yellow-600 hover:border-yellow-600"
               data-disable-with="Cancelling…"
               phx-target={@myself}
               phx-click="cancel">
              <svg class="-ml-1 mr-1 h-5 w-5 text-gray-500 group-hover:text-yellow-500" fill="currentColor" viewBox="0 0 20 20"><path d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
              Cancel
            </a>
          <% end %>

          <%= if can?(:retry_jobs, @access) and runnable?(@job) do %>
            <a id="detail-retry"
               href="#"
               class="group flex items-center ml-3 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none hover:text-blue-500 hover:border-blue-600"
               data-disable-with="Running…"
               phx-target={@myself}
               phx-click="retry">
              <svg class="-ml-1 mr-1 h-5 w-5 text-gray-500 group-hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
              Run Now
            </a>
          <% end %>

          <%= if can?(:retry_jobs, @access) and retryable?(@job) do %>
            <a id="detail-retry"
               href="#"
               class="group flex items-center ml-3 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none hover:text-blue-500 dark:hover:text-blue-400 hover:border-blue-600"
               data-disable-with="Retrying…"
               phx-target={@myself}
               phx-click="retry">
              <svg class="-ml-1 mr-1 h-5 w-5 text-gray-500 group-hover:text-blue-500 dark:group-hover:text-blue-400" fill="currentColor" viewBox="0 0 20 20"><path d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
              Retry
            </a>
          <% end %>

          <%= if can?(:delete_jobs, @access) and deletable?(@job) do %>
            <a id="detail-delete"
               href="#"
               class="group flex items-center ml-3 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none hover:text-red-500 hover:border-red-600"
               data-confirm="Are you sure you want to delete this job?"
               data-disable-with="Deleting…"
               phx-target={@myself}
               phx-click="delete">
              <svg class="-ml-1 mr-1 h-5 w-5 text-gray-500 group-hover:text-red-500" fill="currentColor" viewBox="0 0 20 20"><path d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
              Delete
            </a>
          <% end %>
        </div>
      </div>

      <div class="bg-blue-50 dark:bg-blue-300 dark:bg-opacity-25 border-b border-gray-200 dark:border-gray-700 px-3 py-6">
        <div>
          <span class="text-md text-gray-500 dark:text-gray-400 tabular"><%= @job.id %></span>
          <span class="text-lg font-bold text-gray-900 dark:text-gray-200 ml-1"><%= @job.worker %></span>
        </div>

        <div class="text-sm flex justify-left pt-2 text-gray-900 dark:text-gray-200">
          <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">Queue</span> <%= @job.queue %></div>
          <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">Attempt</span> <%= @job.attempt %> of <%= @job.max_attempts %></div>
          <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">Priority</span> <%= @job.priority %></div>
          <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">Tags</span> <%= formatted_tags(@job) %></div>
          <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">Node</span> <%= attempted_by(@job) %></div>
          <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">Queue Time</span> <%= Timing.queue_time(@job) %></div>
          <div class="mr-6"><span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">Run Time</span> <%= Timing.run_time(@job) %></div>
        </div>
      </div>

      <div class="flex justify-center items-center px-3 pt-6 pb-5">
        <TimelineComponent.render job={@job} state="inserted" />
        <TimelineComponent.render job={@job} state="scheduled" />
        <TimelineComponent.render job={@job} state="executing" />
        <TimelineComponent.render job={@job} state="cancelled" />
        <TimelineComponent.render job={@job} state="discarded" />
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="font-semibold mb-3">Args</h3>
        <pre><code class="font-mono text-sm text-gray-500 dark:text-gray-300 overflow-x-scroll"><%= inspect(@job.args, charlists: :as_lists, pretty: true) %></code></pre>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="font-semibold mb-3">Meta</h3>
        <pre><code class="font-mono text-sm text-gray-500 dark:text-gray-300 overflow-x-scroll"><%= inspect(@job.meta, charlists: :as_lists, pretty: true) %></code></pre>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="font-semibold mb-3">Errors</h3>

        <%= if Enum.any?(@job.errors) do %>
          <%= for %{"at" => at, "attempt" => attempt, "error" => error} <- Enum.reverse(@job.errors) do %>
            <div class="mt-3">
              <h4 class="text-sm mb-2">Attempt <%= attempt %> (<%= iso8601_to_words(at) %>)</h4>
              <pre><code class="font-mono text-sm text-gray-500 dark:text-gray-300 overflow-x-scroll"><%= error %></code></pre>
            </div>
          <% end %>
        <% else %>
          <code class="font-mono text-sm text-gray-500">No Errors</code>
        <% end %>
      </div>
    </div>
    """
  end

  # Handlers

  def handle_event("close", _params, socket) do
    send(self(), {:params, :none})

    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    if can?(:cancel_jobs, socket.assigns.access) do
      send(self(), {:cancel_job, socket.assigns.job})
    end

    {:noreply, socket}
  end

  def handle_event("delete", _params, socket) do
    if can?(:delete_jobs, socket.assigns.access) do
      send(self(), {:delete_job, socket.assigns.job})
    end

    {:noreply, socket}
  end

  def handle_event("retry", _params, socket) do
    if can?(:retry_jobs, socket.assigns.access) do
      send(self(), {:retry_job, socket.assigns.job})
    end

    {:noreply, socket}
  end
end
