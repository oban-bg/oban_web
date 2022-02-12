defmodule Oban.Web.Jobs.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Jobs.TimelineComponent
  alias Oban.Web.{Resolver, Timing}

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="job-details">
      <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
        <%= live_patch to: oban_path(:jobs, @params), id: "back-link", class: "flex items-center hover:text-blue-500", "data-title": "Back to jobs", "phx-hook": "Tippy" do %>
          <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd"></path></svg>
          <span class="text-lg font-bold ml-2">Job Details</span>
        <% end %>

        <div class="flex">
          <%= if can?(:cancel_jobs, @access) and cancelable?(@job) do %>
            <a id="detail-cancel"
               href="#"
               class="group flex items-center ml-4 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-yellow-600 hover:border-yellow-600"
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
               class="group flex items-center ml-3 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-blue-500 hover:border-blue-600"
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
               class="group flex items-center ml-3 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-blue-500 dark:hover:text-blue-400 hover:border-blue-600"
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
               class="group flex items-center ml-3 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-red-500 hover:border-red-600"
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
        <div class="flex justify-between">
          <div>
            <span class="text-md text-gray-500 dark:text-gray-400 tabular"><%= @job.id %></span>
            <span class="text-lg font-bold text-gray-900 dark:text-gray-200 ml-1"><%= @job.worker %></span>
          </div>

          <div>
            <%= if @job.meta["recorded"] do %>
              <span id="is-recorded" data-title="Recording Enabled" phx-hook="Tippy">
                <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
              </span>
            <% end %>

            <%= if @job.meta["encrypted"] do %>
              <span id="is-encrypted" data-title="Encryption Enabled" phx-hook="Tippy">
                <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path></svg>
              </span>
            <% end %>

            <%= if @job.meta["structured"] do %>
              <span id="is-structured" data-title="Structure Enabled" phx-hook="Tippy">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M3 14h18m-9-4v8m-7 0h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg>
              </span>
            <% end %>
          </div>
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
        <h3 class="flex font-semibold mb-3 space-x-2">
          <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
          <span>Args</span>
        </h3>
        <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all"><%= format_args(@job, @resolver) %></pre>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2">
          <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14"></path></svg>
          <span>Meta</span>
        </h3>
        <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all"><%= format_meta(@job, @resolver) %></pre>
      </div>

      <%= if recorded_job?(@job) do %>
        <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
          <h3 class="flex font-semibold mb-3 space-x-2">
            <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
            <span>Recorded Output</span>
          </h3>
          <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all"><%= format_recorded(@job) %></pre>
        </div>
      <% end %>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2">
          <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
          <span>Errors</span>
        </h3>

        <%= if Enum.any?(@job.errors) do %>
          <%= for %{"at" => at, "attempt" => attempt, "error" => error} <- Enum.reverse(@job.errors) do %>
            <div class="mb-12">
              <h4 class="mb-3 flex items-center space-x-2">
                <div class="text-sm font-semibold">Attempt <%= attempt %>&mdash;<%= iso8601_to_words(at) %></div>
                <div id={at} data-title={at} phx-hook="Tippy">
                  <svg class="w-5 h-5 text-gray-500 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                </div>
              </h4>
              <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all"><%= error %></pre>
            </div>
          <% end %>
        <% else %>
          <pre class="font-mono text-sm text-gray-500 dark:text-gray-400">No Errors</pre>
        <% end %>
      </div>
    </div>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
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

  # Helpers

  defp recorded_job?(%{meta: meta}), do: meta["recorded"] == true

  defp format_args(job, resolver) do
    resolver = if function_exported?(resolver, :format_job_args, 1), do: resolver, else: Resolver

    resolver.format_job_args(job)
  end

  defp format_meta(job, resolver) do
    resolver = if function_exported?(resolver, :format_job_meta, 1), do: resolver, else: Resolver

    resolver.format_job_meta(job)
  end

  defp format_recorded(%{meta: meta}) do
    case meta do
      %{"recorded" => true, "return" => value} ->
        value
        |> Base.decode64!(padding: false)
        |> :erlang.binary_to_term([:safe])
        |> inspect(charlists: :as_lists, pretty: true)

      _ ->
        "No Recording Yet"
    end
  end
end
