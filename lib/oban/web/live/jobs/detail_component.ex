defmodule Oban.Web.Jobs.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Jobs.{HistoryChartComponent, TimelineComponent}
  alias Oban.Web.{Resolver, Timing}

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="job-details">
      <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
        <button
          id="back-link"
          class="flex items-center hover:text-blue-500 cursor-pointer bg-transparent border-0 p-0"
          data-escape-back={true}
          data-title="Back to jobs"
          phx-hook="HistoryBack"
          type="button"
        >
          <Icons.arrow_left class="w-5 h-5" />
          <span class="text-lg font-bold ml-2">{@job.worker}</span>
        </button>

        <div class="flex space-x-3">
          <div :if={@job.meta["recorded"]} class="group flex items-center pl-16 -ml-16">
            <span class="inline-flex items-center justify-center h-9 pl-2.5 pr-2.5 group-hover:pr-4 rounded-full text-sm font-medium bg-violet-100 text-violet-700 dark:bg-violet-700/70 dark:text-violet-200 transition-all duration-200">
              <Icons.camera class="h-4 w-4 shrink-0" />
              <span class="max-w-0 overflow-hidden group-hover:max-w-24 group-hover:ml-1.5 transition-all duration-200 whitespace-nowrap">
                Recorded
              </span>
            </span>
          </div>

          <div :if={@job.meta["encrypted"]} class="group flex items-center pl-16 -ml-16">
            <span class="inline-flex items-center justify-center h-9 pl-2.5 pr-2.5 group-hover:pr-4 rounded-full text-sm font-medium bg-violet-100 text-violet-700 dark:bg-violet-700/70 dark:text-violet-200 transition-all duration-200">
              <Icons.lock_closed class="h-4 w-4 shrink-0" />
              <span class="max-w-0 overflow-hidden group-hover:max-w-24 group-hover:ml-1.5 transition-all duration-200 whitespace-nowrap">
                Encrypted
              </span>
            </span>
          </div>

          <div :if={@job.meta["structured"]} class="group flex items-center pl-16 -ml-16">
            <span class="inline-flex items-center justify-center h-9 pl-2.5 pr-2.5 group-hover:pr-4 rounded-full text-sm font-medium bg-violet-100 text-violet-700 dark:bg-violet-700/70 dark:text-violet-200 transition-all duration-200">
              <Icons.table_cells class="h-4 w-4 shrink-0" />
              <span class="max-w-0 overflow-hidden group-hover:max-w-24 group-hover:ml-1.5 transition-all duration-200 whitespace-nowrap">
                Structured
              </span>
            </span>
          </div>

          <%= if can?(:cancel_jobs, @access) and cancelable?(@job) do %>
            <button
              id="detail-cancel"
              class="group flex items-center cursor-pointer text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-yellow-600 hover:border-yellow-600"
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
              class="group flex items-center cursor-pointer text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-blue-500 hover:border-blue-600"
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
              class="group flex items-center cursor-pointer text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-blue-500 dark:hover:text-blue-400 hover:border-blue-600"
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
              class="group flex items-center cursor-pointer text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-red-500 hover:border-red-600"
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

      <div class="grid grid-cols-3 gap-6 px-3 py-6">
        <div class="col-span-2">
          <TimelineComponent.render job={@job} os_time={@os_time} />
        </div>

        <div class="col-span-1">
          <div class="grid grid-cols-3 gap-4 mb-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-md">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Attempted By
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {attempted_by(@job)}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Wait Time
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {Timing.queue_time(@job)}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Exec Time
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {Timing.run_time(@job)}
              </span>
            </div>
          </div>

          <div class="grid grid-cols-3 gap-4 mb-4 px-3">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                ID
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200 tabular">
                {@job.id}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Queue
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {@job.queue}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Attempt
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {@job.attempt} of {@job.max_attempts}
              </span>
            </div>
          </div>

          <div class="grid grid-cols-3 gap-4 px-3">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Priority
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {@job.priority}
              </span>
            </div>

            <div class="flex flex-col col-span-2">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Tags
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {formatted_tags(@job)}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <.live_component
          id="detail-history-chart"
          module={HistoryChartComponent}
          job={@job}
          history={@history}
        />
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
          <Icons.command_line />
          <span>Args</span>
        </h3>
        <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all">{format_args(@job, @resolver)}</pre>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
          <Icons.hashtag />
          <span>Meta</span>
        </h3>
        <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all">{format_meta(@job, @resolver)}</pre>
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
                  Attempt {attempt}&mdash;{Timing.datetime_to_words(at)}
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
    Resolver.call_with_fallback(resolver, :format_job_args, [job])
  end

  defp format_meta(job, resolver) do
    Resolver.call_with_fallback(resolver, :format_job_meta, [job])
  end

  defp format_recorded(%{meta: meta} = job, resolver) do
    case meta do
      %{"recorded" => true, "return" => value} ->
        Resolver.call_with_fallback(resolver, :format_recorded, [value, job])

      _ ->
        "No Recording Yet"
    end
  end
end
