defmodule Oban.Web.Jobs.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Jobs.TimelineComponent
  alias Oban.Web.{Resolver, Timing}

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="job-details">
      <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
        <.link
          patch={oban_path(:jobs, @params)}
          id="back-link"
          class="flex items-center hover:text-blue-500"
          data-title="Back to jobs"
          phx-hook="Tippy"
        >
          <Icons.arrow_left class="w-5 h-5" />
          <span class="text-lg font-bold ml-2">Job Details</span>
        </.link>

        <div class="flex">
          <%= if can?(:cancel_jobs, @access) and cancelable?(@job) do %>
            <button
              id="detail-cancel"
              class="group flex items-center ml-4 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-yellow-600 hover:border-yellow-600"
              data-disable-with="Cancelling…"
              phx-target={@myself}
              phx-click="cancel"
              type="button"
            >
              <Icons.x_circle class="-ml-1 mr-1 h-5 w-5 text-gray-500 group-hover:text-yellow-500" />
              Cancel
            </button>
          <% end %>

          <%= if can?(:retry_jobs, @access) and runnable?(@job) do %>
            <button
              id="detail-retry"
              class="group flex items-center ml-3 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-blue-500 hover:border-blue-600"
              data-disable-with="Running…"
              phx-target={@myself}
              phx-click="retry"
              type="button"
            >
              <Icons.arrow_right_circle class="-ml-1 mr-1 h-5 w-5 text-gray-500 group-hover:text-blue-500" />
              Run Now
            </button>
          <% end %>

          <%= if can?(:retry_jobs, @access) and retryable?(@job) do %>
            <button
              id="detail-retry"
              class="group flex items-center ml-3 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-blue-500 dark:hover:text-blue-400 hover:border-blue-600"
              data-disable-with="Retrying…"
              phx-target={@myself}
              phx-click="retry"
              type="button"
            >
              <Icons.arrow_path class="-ml-1 mr-1 h-5 w-5 text-gray-500 group-hover:text-blue-500" />
              Retry
            </button>
          <% end %>

          <%= if can?(:delete_jobs, @access) and deletable?(@job) do %>
            <button
              id="detail-delete"
              class="group flex items-center ml-3 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-red-500 hover:border-red-600"
              data-confirm="Are you sure you want to delete this job?"
              data-disable-with="Deleting…"
              phx-target={@myself}
              phx-click="delete"
              type="button"
            >
              <Icons.trash class="-ml-1 mr-1 h-5 w-5 text-gray-500 group-hover:text-red-500" /> Delete
            </button>
          <% end %>
        </div>
      </div>

      <div class="bg-blue-50 dark:bg-blue-300 dark:bg-opacity-25 border-b border-gray-200 dark:border-gray-700 px-3 py-6">
        <div class="flex justify-between">
          <div>
            <span class="text-md text-gray-500 dark:text-gray-400 tabular">{@job.id}</span>
            <span class="text-lg font-bold text-gray-900 dark:text-gray-200 ml-1">
              {@job.worker}
            </span>
          </div>

          <div>
            <%= if @job.meta["recorded"] do %>
              <span id="is-recorded" data-title="Recording Enabled" phx-hook="Tippy">
                <Icons.camera />
              </span>
            <% end %>

            <%= if @job.meta["encrypted"] do %>
              <span id="is-encrypted" data-title="Encryption Enabled" phx-hook="Tippy">
                <Icons.lock_closed />
              </span>
            <% end %>

            <%= if @job.meta["structured"] do %>
              <span id="is-structured" data-title="Structure Enabled" phx-hook="Tippy">
                <Icons.table_cells />
              </span>
            <% end %>
          </div>
        </div>

        <div class="text-sm flex justify-left pt-2 text-gray-900 dark:text-gray-200">
          <div class="mr-6">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">
              Queue
            </span>
            {@job.queue}
          </div>
          <div class="mr-6">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">
              Attempt
            </span>
            {@job.attempt} of {@job.max_attempts}
          </div>
          <div class="mr-6">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">
              Priority
            </span>
            {@job.priority}
          </div>
          <div class="mr-6">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">
              Tags
            </span>
            {formatted_tags(@job)}
          </div>
          <div class="mr-6">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">
              Node
            </span>
            {attempted_by(@job)}
          </div>
          <div class="mr-6">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">
              Queue Time
            </span>
            {Timing.queue_time(@job)}
          </div>
          <div class="mr-6">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mr-1">
              Run Time
            </span>
            {Timing.run_time(@job)}
          </div>
        </div>
      </div>

      <div class="flex justify-center items-center px-3 pt-6 pb-5">
        <TimelineComponent.render job={@job} os_time={@os_time} state="inserted" />
        <TimelineComponent.render job={@job} os_time={@os_time} state="scheduled" />
        <TimelineComponent.render job={@job} os_time={@os_time} state="executing" />
        <TimelineComponent.render job={@job} os_time={@os_time} state="cancelled" />
        <TimelineComponent.render job={@job} os_time={@os_time} state="discarded" />
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
          <Icons.command_line />
          <span>Args</span>
        </h3>
        <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all"><%= format_args(@job, @resolver) %></pre>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
          <Icons.hashtag />
          <span>Meta</span>
        </h3>
        <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all"><%= format_meta(@job, @resolver) %></pre>
      </div>

      <%= if @job.meta["recorded"] do %>
        <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
          <h3 class="flex font-semibold mb-3 space-x-2">
            <Icons.camera />
            <span>Recorded Output</span>
          </h3>
          <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all"><%= format_recorded(@job, @resolver) %></pre>
        </div>
      <% end %>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
          <Icons.exclamation_circle />
          <span>Errors</span>
        </h3>

        <%= if Enum.any?(@job.errors) do %>
          <%= for %{"at" => at, "attempt" => attempt, "error" => error} <- Enum.reverse(@job.errors) do %>
            <div class="mb-12">
              <h4 class="mb-3 flex items-center space-x-2">
                <div class="text-sm font-semibold">
                  Attempt {attempt}&mdash;{Timing.iso8601_to_words(at)}
                </div>
                <div id={at} data-title={at} phx-hook="Tippy">
                  <Icons.info_circle class="w-5 h-5 text-gray-500 dark:text-gray-400" />
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

  defp format_args(job, resolver) do
    resolver = if function_exported?(resolver, :format_job_args, 1), do: resolver, else: Resolver

    resolver.format_job_args(job)
  end

  defp format_meta(job, resolver) do
    resolver = if function_exported?(resolver, :format_job_meta, 1), do: resolver, else: Resolver

    resolver.format_job_meta(job)
  end

  defp format_recorded(%{meta: meta} = job, resolver) do
    resolver = if function_exported?(resolver, :format_recorded, 2), do: resolver, else: Resolver

    case meta do
      %{"recorded" => true, "return" => value} -> resolver.format_recorded(value, job)
      _ -> "No Recording Yet"
    end
  end
end
