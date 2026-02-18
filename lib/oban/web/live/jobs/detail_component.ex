defmodule Oban.Web.Jobs.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Jobs.{HistoryChartComponent, TimelineComponent}
  alias Oban.Web.{Resolver, Timing}

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:error_index, fn -> 0 end)
      |> assign_new(:error_sort, fn -> :newest end)

    {:ok, socket}
  end

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
          <span class="text-lg font-bold ml-2">{job_title(@job)}</span>
        </button>

        <div class="flex space-x-3">
          <.status_badge :if={@job.meta["recorded"]} icon="camera" label="Recorded" />
          <.status_badge :if={@job.meta["encrypted"]} icon="lock_closed" label="Encrypted" />
          <.status_badge :if={@job.meta["structured"]} icon="table_cells" label="Structured" />
          <.status_badge :if={@job.meta["decorated"]} icon="sparkles" label="Decorated" />
          <.status_badge :if={@job.meta["rescued"]} icon="life_buoy" label="Rescued" />

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

      <div class="grid grid-cols-3 gap-6 px-3 pt-6">
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

          <div class="mt-4 px-3">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Args
              </span>
              <samp class="font-mono text-sm text-gray-600 dark:text-gray-300 line-clamp-2 break-all">
                {format_args(@job, @resolver)}
              </samp>
            </div>
          </div>
        </div>
      </div>

      <div class="px-3 py-6">
        <.live_component
          id="detail-history-chart"
          module={HistoryChartComponent}
          job={@job}
          history={@history}
        />
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <div class="flex items-center justify-between">
          <button
            id="errors-toggle"
            type="button"
            class="flex items-center space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
            phx-click={toggle_errors()}
          >
            <Icons.chevron_right
              id="errors-chevron"
              class={["w-5 h-5 transition-transform", if(Enum.any?(@job.errors), do: "rotate-90")]}
            />
            <span class="font-semibold">
              Errors
              <span :if={Enum.any?(@job.errors)} class="text-gray-400 font-normal">
                ({length(@job.errors)})
              </span>
            </span>
          </button>

          <div :if={Enum.any?(@job.errors)} class="flex items-center space-x-4">
            <div class="flex items-center text-sm">
              <button
                type="button"
                phx-click="error-sort"
                phx-value-sort="newest"
                phx-target={@myself}
                class={[
                  "px-2 py-1 rounded-l-md border border-r-0 border-gray-300 dark:border-gray-600",
                  if(@error_sort == :newest,
                    do: "bg-gray-200 dark:bg-gray-700 text-gray-800 dark:text-gray-200",
                    else: "bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-750"
                  )
                ]}
              >
                Newest
              </button>
              <button
                type="button"
                phx-click="error-sort"
                phx-value-sort="oldest"
                phx-target={@myself}
                class={[
                  "px-2 py-1 rounded-r-md border border-gray-300 dark:border-gray-600",
                  if(@error_sort == :oldest,
                    do: "bg-gray-200 dark:bg-gray-700 text-gray-800 dark:text-gray-200",
                    else: "bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-750"
                  )
                ]}
              >
                Oldest
              </button>
            </div>

            <div class="flex items-center space-x-1">
              <button
                type="button"
                phx-click="error-nav"
                phx-value-dir="prev"
                phx-target={@myself}
                disabled={@error_index == 0}
                class={[
                  "p-1 rounded",
                  if(@error_index == 0,
                    do: "text-gray-300 dark:text-gray-600 cursor-not-allowed",
                    else: "text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
                  )
                ]}
              >
                <Icons.chevron_left class="w-5 h-5" />
              </button>
              <span class="text-sm text-gray-500 dark:text-gray-400 tabular min-w-[4rem] text-center">
                {@error_index + 1} of {length(@job.errors)}
              </span>
              <button
                type="button"
                phx-click="error-nav"
                phx-value-dir="next"
                phx-target={@myself}
                disabled={@error_index >= length(@job.errors) - 1}
                class={[
                  "p-1 rounded",
                  if(@error_index >= length(@job.errors) - 1,
                    do: "text-gray-300 dark:text-gray-600 cursor-not-allowed",
                    else: "text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
                  )
                ]}
              >
                <Icons.chevron_right class="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>

        <div id="errors-content" class={["mt-3", if(Enum.empty?(@job.errors), do: "hidden")]}>
          <%= if Enum.any?(@job.errors) do %>
            <% sorted_errors = sort_errors(@job.errors, @error_sort) %>
            <% current_error = Enum.at(sorted_errors, @error_index) %>
            <.error_entry error={current_error} />
          <% else %>
            <div class="flex items-center space-x-2 text-gray-400 dark:text-gray-500">
              <Icons.check_circle class="w-5 h-5" />
              <span class="text-sm">No errors recorded</span>
            </div>
          <% end %>
        </div>
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

  def handle_event("error-sort", %{"sort" => sort}, socket) do
    sort = String.to_existing_atom(sort)
    {:noreply, assign(socket, error_sort: sort, error_index: 0)}
  end

  def handle_event("error-nav", %{"dir" => "prev"}, socket) do
    index = max(0, socket.assigns.error_index - 1)
    {:noreply, assign(socket, error_index: index)}
  end

  def handle_event("error-nav", %{"dir" => "next"}, socket) do
    max_index = length(socket.assigns.job.errors) - 1
    index = min(max_index, socket.assigns.error_index + 1)
    {:noreply, assign(socket, error_index: index)}
  end

  # Helpers

  defp sort_errors(errors, :newest), do: Enum.reverse(errors)
  defp sort_errors(errors, :oldest), do: errors

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

  attr :error, :map, required: true

  defp error_entry(assigns) do
    {message, stacktrace} = parse_error(assigns.error["error"])
    assigns = assign(assigns, message: message, stacktrace: stacktrace)

    ~H"""
    <div class="mb-8 p-4 bg-gray-50 dark:bg-gray-800 rounded-md">
      <div class="flex items-center justify-between mb-3 text-sm text-gray-500 dark:text-gray-400">
        <span>Attempt {@error["attempt"]}</span>
        <span>{Timing.datetime_to_words(@error["at"])} <span class="text-gray-400 dark:text-gray-500">({@error["at"]})</span></span>
      </div>

      <div class="font-mono text-base font-medium text-gray-800 dark:text-gray-200 mb-4">
        {@message}
      </div>

      <div :if={@stacktrace != []} class="space-y-1">
        <div
          :for={frame <- @stacktrace}
          class="font-mono text-sm text-gray-600 dark:text-gray-400 py-1.5 px-2 bg-white dark:bg-gray-900 rounded border-l-2 border-gray-300 dark:border-gray-600"
        >
          {frame}
        </div>
      </div>
    </div>
    """
  end

  defp parse_error(error) do
    case String.split(error, "\n", parts: 2) do
      [message, rest] ->
        stacktrace =
          rest
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        {message, stacktrace}

      [message] ->
        {message, []}
    end
  end

  defp toggle_errors do
    %JS{}
    |> JS.toggle(to: "#errors-content", in: "fade-in-scale", out: "fade-out-scale")
    |> JS.add_class("rotate-90", to: "#errors-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#errors-chevron.rotate-90")
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true

  defp status_badge(assigns) do
    ~H"""
    <div class="group flex items-center cursor-default select-none">
      <span class="inline-flex items-center justify-center h-9 pl-2.5 pr-2.5 group-hover:pr-4 rounded-full text-sm font-medium bg-violet-100 text-violet-700 dark:bg-violet-700/70 dark:text-violet-200 transition-all duration-200">
        <.status_icon name={@icon} />
        <span class="max-w-0 overflow-hidden group-hover:max-w-24 group-hover:ml-1.5 transition-all duration-200 whitespace-nowrap">
          {@label}
        </span>
      </span>
    </div>
    """
  end

  defp job_title(job), do: Map.get(job.meta, "decorated_name", job.worker)

  defp status_icon(%{name: "camera"} = assigns), do: ~H[<Icons.camera class="h-4 w-4 shrink-0" />]
  defp status_icon(%{name: "lock_closed"} = assigns), do: ~H[<Icons.lock_closed class="h-4 w-4 shrink-0" />]
  defp status_icon(%{name: "table_cells"} = assigns), do: ~H[<Icons.table_cells class="h-4 w-4 shrink-0" />]
  defp status_icon(%{name: "sparkles"} = assigns), do: ~H[<Icons.sparkles class="h-4 w-4 shrink-0" />]
  defp status_icon(%{name: "life_buoy"} = assigns), do: ~H[<Icons.life_buoy class="h-4 w-4 shrink-0" />]
end
