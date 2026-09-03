defmodule Oban.Web.Jobs.DetailComponent do
  use Oban.Web, :live_component

  import Oban.Web.FormComponents

  alias Oban.Web.Jobs.{Form, HistoryChartComponent, Recorded, TimelineComponent}
  alias Oban.Web.{Resolver, Timing}

  @hidden_meta ~w(return signal storage size safe_decode)

  @impl Phoenix.LiveComponent
  def update(%{failure: failure}, socket) do
    {:ok,
     assign(socket, errors: Form.format_failure(failure), invalid: Form.invalid_fields(failure))}
  end

  # Saving stores what the engine accepted, which may differ from what was typed, so the form
  # reseeds from the job as it is now stored.
  def update(%{reseed: true}, socket) do
    {:ok, assign_seed(socket, socket.assigns.job)}
  end

  def update(assigns, socket) do
    auto_open_diagnostics? =
      assigns[:diagnostics] != nil and
        socket.assigns[:diagnostics] == nil and
        is_struct(assigns[:job]) and assigns.job.state == "executing"

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:error_index, fn -> 0 end)
      |> assign_new(:error_sort, fn -> :desc end)
      |> assign_new(:errors, fn -> [] end)
      |> assign_new(:invalid, fn -> [] end)
      |> assign_new(:queues, fn -> [] end)
      |> assign_new(:compensating_job, fn -> nil end)
      |> assign_new(:diagnostics_open?, fn -> false end)
      |> assign_recorded()
      |> assign_form()
      |> then(fn socket ->
        if auto_open_diagnostics?, do: assign(socket, :diagnostics_open?, true), else: socket
      end)

    {:ok, socket}
  end

  # Refreshes replace the job every second and opening another job swaps it entirely. Freshness
  # is per field: an untouched field tracks the live job, while a field with edits in progress
  # keeps them.
  defp assign_form(socket) do
    job = socket.assigns.job

    if Map.get(socket.assigns, :seeded) == job.id do
      fresh = Form.seed(job)
      %{baseline: baseline, form: form} = socket.assigns

      assign(socket, baseline: fresh, form: merge_fresh(form, baseline, fresh))
    else
      assign_seed(socket, job)
    end
  end

  defp assign_seed(socket, job) do
    form = Form.seed(job)

    assign(socket, baseline: form, errors: [], form: form, invalid: [], seeded: job.id)
  end

  defp assign_recorded(socket) do
    %{job: job, resolver: resolver} = socket.assigns

    key = {job.id, job.meta["return"]}

    # The job is re-assigned on every refresh, so fetched output is only recomputed when the
    # recording itself changes, otherwise the panel would flicker back to a load button each
    # second.
    if Map.has_key?(socket.assigns, :recorded_key) and socket.assigns.recorded_key == key do
      socket
    else
      assign(socket,
        recorded_key: key,
        recorded_size: Recorded.size(job),
        recorded_state: initial_recorded_state(job, resolver)
      )
    end
  end

  defp initial_recorded_state(job, resolver) do
    case Recorded.status(job) do
      :disabled ->
        {:error, :disabled}

      :none ->
        {:error, :none}

      :inline ->
        if oversized?(Recorded.size(job), size_limit(resolver)) do
          {:error, :too_large}
        else
          format_recorded(job.meta["return"], job, resolver)
        end

      :external ->
        if oversized?(Recorded.size(job), size_limit(resolver)) do
          {:error, :too_large}
        else
          :idle
        end
    end
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    assigns =
      assign(assigns,
        changed?: assigns.form != assigns.baseline,
        confirm_leave: assigns.form != assigns.baseline && "Discard unsaved changes?"
      )

    ~H"""
    <div id="job-details">
      <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
        <h2 class="min-w-0">
          <button
            id="back-link"
            class="flex items-center min-w-0 max-w-full hover:text-blue-500 cursor-pointer bg-transparent border-0 p-0 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
            data-confirm-back={@confirm_leave}
            data-escape-back={true}
            phx-hook="HistoryBack"
            type="button"
          >
            <Icons.icon name="icon-arrow-left" class="w-5 h-5 shrink-0" />
            <span class="text-lg font-bold ml-2 truncate">{job_title(@job)}</span>
          </button>
        </h2>

        <div class="flex shrink-0 space-x-3">
          <Core.status_badge
            :if={@job.meta["batch"]}
            id="status-batch"
            icon="square_2x2"
            label="Batch"
          />
          <Core.status_badge
            :if={@job.meta["workflow"]}
            id="status-workflow"
            icon="rectangle_group"
            label="Workflow"
          />
          <Core.status_badge
            :if={@job.meta["chunk"]}
            id="status-chunk"
            icon="user_group"
            label="Chunk"
          />
          <Core.status_badge :if={@job.meta["chain"]} id="status-chain" icon="link" label="Chain" />
          <Core.status_badge
            :if={@job.meta["recorded"]}
            id="status-recorded"
            icon="camera"
            label="Recorded"
          />
          <Core.status_badge
            :if={signal_status(@job) != :none}
            id="status-signal"
            icon="signal"
            label="Signal"
          />
          <Core.status_badge
            :if={@job.meta["encrypted"]}
            id="status-encrypted"
            icon="lock_closed"
            label="Encrypted"
          />
          <Core.status_badge
            :if={@job.meta["structured"]}
            id="status-structured"
            icon="table_cells"
            label="Structured"
          />
          <Core.status_badge
            :if={@job.meta["decorated"]}
            id="status-decorated"
            icon="sparkles"
            label="Decorated"
          />
          <Core.status_badge
            :if={@job.meta["rescued"]}
            id="status-rescued"
            icon="life_buoy"
            label="Rescued"
          />

          <Core.icon_button
            id="detail-cancel"
            icon="x_circle"
            label="Cancel"
            color="yellow"
            tooltip={
              if cancelable?(@job),
                do: "Cancel this job",
                else: "Only unfinished jobs can be cancelled"
            }
            disabled={not cancelable?(@job) or not can?(:cancel_jobs, @access)}
            phx-target={@myself}
            phx-click="cancel"
          />

          <Core.icon_button
            id="detail-retry"
            icon="arrow_path"
            label="Retry"
            color="blue"
            tooltip={retry_tooltip(@job)}
            disabled={not (runnable?(@job) or retryable?(@job)) or not can?(:retry_jobs, @access)}
            phx-target={@myself}
            phx-click="retry"
          />

          <Core.icon_button
            id="detail-delete"
            icon="trash"
            label="Delete"
            color="red"
            tooltip={
              if deletable?(@job),
                do: "Delete this job",
                else: "Executing jobs can't be deleted"
            }
            disabled={not deletable?(@job) or not can?(:delete_jobs, @access)}
            confirm={"Delete job #{@job.id}? This can't be undone."}
            phx-target={@myself}
            phx-click="delete"
          />

          <Core.icon_button
            id="detail-edit"
            icon="pencil_square"
            label="Edit"
            color="violet"
            tooltip={if executing?(@job), do: "Executing jobs can't be edited", else: "Edit this job"}
            disabled={executing?(@job) or not can?(:update_jobs, @access)}
            phx-click={scroll_to_edit()}
          />
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-5 gap-6 px-3 pt-6">
        <div class="lg:col-span-3">
          <TimelineComponent.render job={@job} os_time={@os_time} />
        </div>

        <div class="lg:col-span-2">
          <dl class="grid grid-cols-3 gap-4 mb-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-md">
            <div class="flex flex-col">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                ID
              </dt>
              <dd class="text-base text-gray-800 dark:text-gray-200 tabular">{@job.id}</dd>
            </div>

            <div class="flex flex-col">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Wait Time
              </dt>
              <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
                {Timing.queue_time(@job)}
              </dd>
            </div>

            <div class="flex flex-col">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Exec Time
              </dt>
              <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
                {Timing.run_time(@job)}
              </dd>
            </div>

            <div class="flex flex-col min-w-0">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Attempted By
              </dt>
              <dd class="text-base text-gray-800 dark:text-gray-200 truncate">
                {attempted_by(@job)}
              </dd>
            </div>

            <div class="flex flex-col">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Snoozed
              </dt>
              <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
                {@job.meta["snoozed"] || "—"}
              </dd>
            </div>

            <div class="flex flex-col">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Rescued
              </dt>
              <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
                {@job.meta["rescued"] || "—"}
              </dd>
            </div>
          </dl>

          <dl class="grid grid-cols-3 gap-4 mb-4 px-3">
            <div class="flex flex-col min-w-0">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Queue
              </dt>
              <dd>
                <.link
                  id="queue-link"
                  patch={oban_path([:queues, @job.queue])}
                  data-confirm={@confirm_leave}
                  class="inline-flex items-center max-w-full text-base text-gray-800 dark:text-gray-200 hover:text-blue-500 dark:hover:text-blue-400 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
                  data-title="View queue details"
                  phx-hook="Tippy"
                >
                  <span class="truncate">{@job.queue}</span>
                </.link>
              </dd>
            </div>

            <div class="flex flex-col">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Attempt
              </dt>
              <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
                {@job.attempt} of {@job.max_attempts}
              </dd>
            </div>

            <div class="flex flex-col">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Priority
              </dt>
              <dd class="text-base text-gray-800 dark:text-gray-200 tabular">{@job.priority}</dd>
            </div>

            <div :if={@job.meta["workflow_id"]} class="flex flex-col col-span-3 min-w-0">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Workflow
              </dt>
              <dd>
                <.link
                  id="workflow-link"
                  navigate={oban_path([:workflows, @job.meta["workflow_id"]])}
                  data-confirm={@confirm_leave}
                  class="inline-flex items-center max-w-full text-base text-gray-800 dark:text-gray-200 hover:text-blue-500 dark:hover:text-blue-400 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
                  data-title="View workflow"
                  phx-hook="Tippy"
                >
                  <Icons.icon
                    name="icon-rectangle-group"
                    class="w-4 h-4 mr-1.5 shrink-0 text-violet-500"
                  />
                  <span class="truncate">{workflow_display_name(@job)}</span>
                </.link>
              </dd>
            </div>

            <div :if={@job.meta["origin_job_id"]} class="flex flex-col col-span-3 min-w-0">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Rolls Back
              </dt>
              <dd>
                <.link
                  id="origin-job-link"
                  navigate={oban_path([:jobs, @job.meta["origin_job_id"]])}
                  data-confirm={@confirm_leave}
                  class="inline-flex items-center max-w-full text-base text-gray-800 dark:text-gray-200 hover:text-blue-500 dark:hover:text-blue-400 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
                  data-title="View the job this rolls back"
                  phx-hook="Tippy"
                >
                  <Icons.icon
                    name="icon-arrow-path-rounded"
                    class="w-4 h-4 mr-1.5 shrink-0 text-violet-500"
                  />
                  <span class="truncate">{@job.meta["origin_name"]}</span>
                </.link>
              </dd>
            </div>

            <div :if={@compensating_job} class="flex flex-col col-span-3 min-w-0">
              <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Rollback
              </dt>
              <dd>
                <.link
                  id="compensating-job-link"
                  navigate={oban_path([:jobs, @compensating_job.id])}
                  data-confirm={@confirm_leave}
                  class="inline-flex items-center max-w-full text-base text-gray-800 dark:text-gray-200 hover:text-blue-500 dark:hover:text-blue-400 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
                  data-title="View the job rolling this back"
                  phx-hook="Tippy"
                >
                  <Icons.icon
                    name="icon-arrow-path-rounded"
                    class="w-4 h-4 mr-1.5 shrink-0 text-violet-500"
                  />
                  <span class="truncate">{@compensating_job.state}</span>
                </.link>
              </dd>
            </div>
          </dl>
        </div>
      </div>

      <.job_data_section
        job={@job}
        resolver={@resolver}
        myself={@myself}
        recorded_size={@recorded_size}
        recorded_state={@recorded_state}
      />

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <button
          id="diagnostics-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
          aria-controls="diagnostics-content"
          aria-expanded={to_string(@diagnostics_open?)}
          phx-click="toggle-diagnostics"
          phx-target={@myself}
        >
          <Icons.icon
            name="icon-chevron-right"
            id="diagnostics-chevron"
            class={["w-5 h-5 transition-transform", if(@diagnostics_open?, do: "rotate-90")]}
          />
          <span class="font-semibold">Diagnostics</span>
          <.pro_badge id="diagnostics-badge" tooltip="Diagnostics for executing Oban.Pro.Worker jobs" />
          <.stale_badge :if={@diagnostics && not executing?(@job)} />
        </button>

        <div :if={@diagnostics_open?} id="diagnostics-content" class="mt-3">
          <%= if @diagnostics do %>
            <div class="grid grid-cols-2 gap-4">
              <div class="bg-gray-50 dark:bg-gray-800 rounded-md p-4">
                <div class="flex justify-between items-center mb-3">
                  <h3 class="font-medium text-xs uppercase text-gray-500 dark:text-gray-400">
                    Process Info
                  </h3>
                  <span class="text-xs tabular text-gray-500 dark:text-gray-400">
                    Refreshed at {format_diagnostics_time(@diagnostics_at)} UTC
                  </span>
                </div>
                <dl class="grid grid-cols-2 gap-3">
                  <div class="flex flex-col">
                    <dt class="text-xs font-medium text-gray-600 dark:text-gray-300">Node</dt>
                    <dd class="text-sm text-gray-800 dark:text-gray-200">
                      {@diagnostics["node"]}
                    </dd>
                  </div>
                  <div class="flex flex-col">
                    <dt class="text-xs font-medium text-gray-600 dark:text-gray-300">PID</dt>
                    <dd class="text-sm tabular text-gray-800 dark:text-gray-200">
                      {@diagnostics["pid"]}
                    </dd>
                  </div>
                  <div class="flex flex-col">
                    <dt class="text-xs font-medium text-gray-600 dark:text-gray-300">Status</dt>
                    <dd class="text-sm tabular text-gray-800 dark:text-gray-200">
                      {format_status(@diagnostics["info"]["status"])}
                    </dd>
                  </div>
                  <div class="flex flex-col">
                    <dt class="text-xs font-medium text-gray-600 dark:text-gray-300">Memory</dt>
                    <dd class="text-sm tabular text-gray-800 dark:text-gray-200">
                      {format_bytes(@diagnostics["info"]["memory"])}
                    </dd>
                  </div>
                  <div class="flex flex-col">
                    <dt class="text-xs font-medium text-gray-600 dark:text-gray-300">
                      Message Queue
                    </dt>
                    <dd class="text-sm tabular text-gray-800 dark:text-gray-200">
                      {format_number(@diagnostics["info"]["message_queue_len"])}
                    </dd>
                  </div>
                  <div class="flex flex-col">
                    <dt class="text-xs font-medium text-gray-600 dark:text-gray-300">
                      Reductions
                    </dt>
                    <dd class="text-sm tabular text-gray-800 dark:text-gray-200">
                      {format_number(@diagnostics["info"]["reductions"])}
                    </dd>
                  </div>
                  <div class="flex flex-col">
                    <dt class="text-xs font-medium text-gray-600 dark:text-gray-300">
                      Heap Size
                    </dt>
                    <dd class="text-sm tabular text-gray-800 dark:text-gray-200">
                      {format_number(@diagnostics["info"]["heap_size"])}
                    </dd>
                  </div>
                  <div class="flex flex-col">
                    <dt class="text-xs font-medium text-gray-600 dark:text-gray-300">
                      Stack Size
                    </dt>
                    <dd class="text-sm tabular text-gray-800 dark:text-gray-200">
                      {format_number(@diagnostics["info"]["stack_size"])}
                    </dd>
                  </div>
                </dl>
              </div>

              <div class="relative bg-gray-50 dark:bg-gray-800 rounded-md p-4">
                <div class="flex justify-between items-start mb-3">
                  <h3 class="font-medium text-xs uppercase text-gray-500 dark:text-gray-400">
                    Current Stacktrace
                  </h3>
                  <button
                    :if={@diagnostics["info"]["current_stacktrace"]}
                    type="button"
                    id="copy-stacktrace"
                    class="w-9 h-9 -mr-2 -mt-2 flex items-center justify-center rounded-full text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 hover:bg-white dark:hover:bg-gray-700 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
                    aria-label="Copy stacktrace"
                    data-title="Copy to clipboard"
                    phx-hook="Tippy"
                    phx-click={copy_to_clipboard(@diagnostics["info"]["current_stacktrace"])}
                  >
                    <Icons.icon name="icon-clipboard" class="w-4 h-4" />
                  </button>
                </div>
                <%= if @diagnostics["info"]["current_stacktrace"] do %>
                  <div class="space-y-1 max-h-64 overflow-y-auto">
                    <div
                      :for={frame <- parse_stacktrace(@diagnostics["info"]["current_stacktrace"])}
                      class="font-mono text-xs text-gray-600 dark:text-gray-400 py-1.5 px-2 bg-white dark:bg-gray-900 rounded border-l-2 border-gray-300 dark:border-gray-600"
                    >
                      {frame}
                    </div>
                  </div>
                <% else %>
                  <span class="text-sm text-gray-400 dark:text-gray-500">
                    No stacktrace available
                  </span>
                <% end %>
              </div>
            </div>
          <% else %>
            <div class="flex items-center space-x-2 px-2 text-gray-400 dark:text-gray-500">
              <Icons.icon name="icon-clock" class="w-5 h-5" />
              <span class="text-sm">
                <%= if executing?(@job) do %>
                  Waiting for diagnostics…
                <% else %>
                  Diagnostics are only available for executing jobs
                <% end %>
              </span>
            </div>
          <% end %>
        </div>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <.live_component
          id="detail-history-chart"
          module={HistoryChartComponent}
          confirm_leave={@confirm_leave}
          job={@job}
          history={@history}
        />
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <button
          id="errors-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
          aria-controls="errors-content"
          aria-expanded={to_string(Enum.any?(@job.errors))}
          phx-click={toggle_errors()}
        >
          <Icons.icon
            name="icon-chevron-right"
            id="errors-chevron"
            class={["w-5 h-5 transition-transform", if(Enum.any?(@job.errors), do: "rotate-90")]}
          />
          <span class="font-semibold">
            Errors
            <span :if={Enum.any?(@job.errors)} class="text-gray-400 dark:text-gray-500 font-normal">
              ({length(@job.errors)})
            </span>
          </span>
        </button>

        <div id="errors-content" class={["mt-3", if(Enum.empty?(@job.errors), do: "hidden")]}>
          <%= if Enum.any?(@job.errors) do %>
            <div class="flex items-center justify-end mb-3 space-x-4">
              <div class="flex items-center text-sm">
                <button
                  type="button"
                  phx-click="error-sort"
                  phx-value-sort="desc"
                  phx-target={@myself}
                  aria-pressed={to_string(@error_sort == :desc)}
                  class={[
                    "px-2 py-1 cursor-pointer rounded-l-md border border-r-0 border-gray-300 dark:border-gray-600 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500",
                    if(@error_sort == :desc,
                      do: "bg-gray-200 dark:bg-gray-700 text-gray-800 dark:text-gray-200",
                      else:
                        "bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700"
                    )
                  ]}
                >
                  Newest
                </button>
                <button
                  type="button"
                  phx-click="error-sort"
                  phx-value-sort="asc"
                  phx-target={@myself}
                  aria-pressed={to_string(@error_sort == :asc)}
                  class={[
                    "px-2 py-1 cursor-pointer rounded-r-md border border-gray-300 dark:border-gray-600 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500",
                    if(@error_sort == :asc,
                      do: "bg-gray-200 dark:bg-gray-700 text-gray-800 dark:text-gray-200",
                      else:
                        "bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700"
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
                  aria-label="Previous error"
                  class={[
                    "p-1 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500",
                    if(@error_index == 0,
                      do: "text-gray-300 dark:text-gray-500 cursor-not-allowed",
                      else:
                        "text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
                    )
                  ]}
                >
                  <Icons.icon name="icon-chevron-left" class="w-5 h-5" />
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
                  aria-label="Next error"
                  class={[
                    "p-1 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500",
                    if(@error_index >= length(@job.errors) - 1,
                      do: "text-gray-300 dark:text-gray-500 cursor-not-allowed",
                      else:
                        "text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
                    )
                  ]}
                >
                  <Icons.icon name="icon-chevron-right" class="w-5 h-5" />
                </button>
              </div>
            </div>

            <.error_entry errors={@job.errors} index={@error_index} sort={@error_sort} />
          <% else %>
            <div class="flex items-center space-x-2 px-2 text-gray-400 dark:text-gray-500">
              <Icons.icon name="icon-check-circle" class="w-5 h-5" />
              <span class="text-sm">No errors recorded</span>
            </div>
          <% end %>
        </div>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <button
          id="edit-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
          aria-controls="edit-content"
          aria-expanded={to_string(not executing?(@job))}
          phx-click={toggle_edit()}
        >
          <Icons.icon
            name="icon-chevron-right"
            id="edit-chevron"
            class={["w-5 h-5 transition-transform", if(not executing?(@job), do: "rotate-90")]}
          />
          <span class="font-semibold">Edit Job</span>
          <span
            :if={executing?(@job)}
            id="edit-hint"
            class="flex items-center"
            data-title="Executing jobs can't be edited"
            phx-hook="Tippy"
          >
            <Icons.icon name="icon-info-circle" class="w-4 h-4 text-gray-400 dark:text-gray-500" />
          </span>
        </button>

        <div id="edit-content" class={["mt-3", if(executing?(@job), do: "hidden")]}>
          <fieldset disabled={executing?(@job) or not can?(:update_jobs, @access)}>
            <form
              id="job-edit-form"
              class="grid grid-cols-4 gap-4 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
              phx-change="form-change"
              phx-submit="save-job"
              phx-target={@myself}
            >
              <.form_field
                label="Worker"
                name="worker"
                value={@form.worker}
                required={true}
                invalid={:worker in @invalid}
              />

              <.select_field
                label="Queue"
                name="queue"
                value={@form.queue}
                options={queue_options(@queues, @form.queue)}
                invalid={:queue in @invalid}
              />

              <.form_field
                label="Priority"
                name="priority"
                value={@form.priority}
                type="number"
                min={0}
                max={9}
                placeholder="0"
                required={true}
                invalid={:priority in @invalid}
              />

              <.form_field
                label="Max Attempts"
                name="max_attempts"
                value={@form.max_attempts}
                type="number"
                min={1}
                placeholder="20"
                required={true}
                invalid={:max_attempts in @invalid}
              />

              <.form_field
                label="Scheduled At"
                name="scheduled_at"
                value={@form.scheduled_at}
                type="datetime-local"
                step={1}
                required={true}
                invalid={:scheduled_at in @invalid}
                hint="Entered and stored in UTC"
              />

              <.form_field
                label="Tags"
                name="tags"
                value={@form.tags}
                placeholder="tag1, tag2"
                colspan="col-span-3"
                hint="Comma separated"
              />

              <.form_field
                label="Args"
                name="args"
                value={@form.args}
                colspan="col-span-4"
                type="textarea"
                placeholder="{}"
                rows={3}
                invalid={:args in @invalid}
                hint="A JSON object"
              />

              <div
                :if={@errors != []}
                id="job-form-errors"
                role="alert"
                class="col-span-4 px-3 py-2 rounded-md bg-red-50 dark:bg-red-900/20 text-sm text-red-700 dark:text-red-300 space-y-1"
              >
                <p :for={error <- @errors}>{error}</p>
              </div>

              <div
                :if={can?(:update_jobs, @access)}
                class="col-span-4 flex justify-end items-center gap-4 pt-4"
              >
                <button
                  type="button"
                  id="detail-discard"
                  disabled={not @changed?}
                  phx-click="discard-changes"
                  phx-target={@myself}
                  class="text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Discard
                </button>
                <button
                  type="submit"
                  id="detail-save"
                  disabled={not @changed?}
                  phx-disable-with="Saving…"
                  class="px-6 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-900 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Save Changes
                </button>
              </div>
            </form>
          </fieldset>
        </div>
      </div>
    </div>
    """
  end

  # Pro Badge

  attr :id, :string, required: true
  attr :tooltip, :string, required: true

  defp pro_badge(assigns) do
    ~H"""
    <span
      id={@id}
      class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-violet-100 text-violet-700 dark:bg-violet-900/50 dark:text-violet-300"
      data-title={@tooltip}
      phx-hook="Tippy"
    >
      Pro
    </span>
    """
  end

  defp stale_badge(assigns) do
    ~H"""
    <span
      id="diagnostics-stale-badge"
      class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-amber-100 text-amber-700 dark:bg-amber-900/50 dark:text-amber-300"
      data-title="Diagnostics data is stale because the job is no longer executing"
      phx-hook="Tippy"
    >
      Stale
    </span>
    """
  end

  # Job Data Section

  attr :job, :map, required: true
  attr :resolver, :any, required: true
  attr :myself, :any, required: true
  attr :recorded_size, :integer, default: nil
  attr :recorded_state, :any, required: true

  defp job_data_section(assigns) do
    ~H"""
    <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
      <button
        id="job-data-toggle"
        type="button"
        class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
        aria-controls="job-data-content"
        aria-expanded="true"
        phx-click={toggle_job_data()}
      >
        <Icons.icon
          name="icon-chevron-right"
          id="job-data-chevron"
          class="w-5 h-5 transition-transform rotate-90"
        />
        <span class="font-semibold">Job Data</span>
      </button>

      <div id="job-data-content" class="mt-3">
        <div class="grid grid-cols-2 gap-4">
          <div id="job-args" class="relative bg-gray-50 dark:bg-gray-800 rounded-md p-4">
            <div class="flex justify-between items-start mb-2">
              <h3 class="font-medium text-xs uppercase text-gray-500 dark:text-gray-400">
                Args
              </h3>
              <button
                type="button"
                id="copy-args"
                class="w-9 h-9 -mr-2 -mt-2 flex items-center justify-center rounded-full text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 hover:bg-white dark:hover:bg-gray-700 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
                aria-label="Copy args"
                data-title="Copy to clipboard"
                phx-hook="Tippy"
                phx-click={copy_to_clipboard(format_args(@job, @resolver))}
              >
                <Icons.icon name="icon-clipboard" class="w-4 h-4" />
              </button>
            </div>
            <pre class="font-mono text-sm text-gray-600 dark:text-gray-400 whitespace-pre-wrap break-all">{format_args(@job, @resolver)}</pre>
          </div>

          <div class="relative bg-gray-50 dark:bg-gray-800 rounded-md p-4">
            <div class="flex justify-between items-start mb-2">
              <h3 class="font-medium text-xs uppercase text-gray-500 dark:text-gray-400">
                Meta
              </h3>
              <button
                type="button"
                id="copy-meta"
                class="w-9 h-9 -mr-2 -mt-2 flex items-center justify-center rounded-full text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 hover:bg-white dark:hover:bg-gray-700 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
                aria-label="Copy meta"
                data-title="Copy to clipboard"
                phx-hook="Tippy"
                phx-click={copy_to_clipboard(format_meta(@job, @resolver))}
              >
                <Icons.icon name="icon-clipboard" class="w-4 h-4" />
              </button>
            </div>
            <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all">{format_meta(@job, @resolver)}</pre>
          </div>
        </div>

        <div :if={@job.meta["recorded"]} id="job-recorded" class="mt-4">
          <div class="relative bg-gray-50 dark:bg-gray-800 rounded-md p-4">
            <div class="flex justify-between items-start mb-2">
              <div class="flex items-center space-x-2">
                <h3 class="font-medium text-xs uppercase text-gray-500 dark:text-gray-400">
                  Recorded Output
                </h3>
                <.pro_badge id="recorded-pro-badge" tooltip="Recording from Oban.Pro.Worker" />
                <span
                  :if={@recorded_size}
                  id="recorded-size"
                  class="text-xs text-gray-400 dark:text-gray-500"
                >
                  {format_bytes(@recorded_size)}
                </span>
              </div>
              <button
                :if={recorded_output(@recorded_state)}
                type="button"
                id="copy-recorded"
                class="w-9 h-9 -mr-2 -mt-2 flex items-center justify-center rounded-full text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 hover:bg-white dark:hover:bg-gray-700 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
                aria-label="Copy recorded output"
                data-title="Copy to clipboard"
                phx-hook="Tippy"
                phx-click={copy_to_clipboard(recorded_output(@recorded_state))}
              >
                <Icons.icon name="icon-clipboard" class="w-4 h-4" />
              </button>
            </div>

            <pre
              :if={recorded_output(@recorded_state)}
              class="font-mono text-sm text-gray-600 dark:text-gray-400 whitespace-pre-wrap break-all"
            >{recorded_output(@recorded_state)}</pre>

            <div :if={@recorded_state == :loading} class="flex items-center space-x-2">
              <Icons.icon
                name="icon-arrow-path"
                class="w-4 h-4 text-gray-400 dark:text-gray-500 animate-spin"
              />
              <span class="text-sm text-gray-500 dark:text-gray-400">Fetching output…</span>
            </div>

            <div :if={recorded_message(@recorded_state)} class="flex items-center space-x-3">
              <button
                :if={loadable?(@job, @recorded_state)}
                type="button"
                id="load-recorded"
                class="flex items-center space-x-1.5 px-3 py-1.5 font-medium text-sm text-gray-600 dark:text-gray-300 border border-gray-300 dark:border-gray-600 rounded-md hover:border-blue-500 hover:text-blue-500 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
                phx-click="load-recorded"
                phx-target={@myself}
              >
                <Icons.icon name="icon-arrow-down-tray" class="w-4 h-4" />
                <span>{if @recorded_state == :idle, do: "Load Output", else: "Try Again"}</span>
              </button>
              <span class="text-sm text-gray-500 dark:text-gray-400">
                {recorded_message(@recorded_state)}
              </span>
            </div>
          </div>
        </div>

        <div :if={signal_status(@job) != :none} class="mt-4">
          <div class="relative bg-gray-50 dark:bg-gray-800 rounded-md p-4">
            <div class="flex justify-between items-start mb-2">
              <div class="flex items-center space-x-2">
                <h3 class="font-medium text-xs uppercase text-gray-500 dark:text-gray-400">
                  {signal_heading(@job)}
                </h3>
                <.pro_badge id="signal-pro-badge" tooltip="Awaitable signal from Oban.Pro.Worker" />
              </div>
              <button
                type="button"
                id="copy-signal"
                class={[
                  "w-9 h-9 -mr-2 -mt-2 flex items-center justify-center rounded-full text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 hover:bg-white dark:hover:bg-gray-700 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500",
                  signal_status(@job) != :received && "invisible"
                ]}
                aria-label="Copy signal"
                data-title="Copy to clipboard"
                phx-hook="Tippy"
                phx-click={copy_to_clipboard(format_signal(@job, @resolver))}
              >
                <Icons.icon name="icon-clipboard" class="w-4 h-4" />
              </button>
            </div>
            <pre class="font-mono text-sm text-gray-600 dark:text-gray-400 whitespace-pre-wrap break-all">{format_signal(@job, @resolver)}</pre>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_async(:fetch_recorded, {:ok, {:ok, payload}}, socket) do
    %{job: job, resolver: resolver} = socket.assigns

    state =
      if oversized?(byte_size(payload), size_limit(resolver)) do
        {:error, :too_large}
      else
        format_recorded(payload, job, resolver)
      end

    {:noreply, assign(socket, recorded_size: byte_size(payload), recorded_state: state)}
  end

  def handle_async(:fetch_recorded, {:ok, {:error, reason}}, socket) do
    {:noreply, assign(socket, recorded_state: {:error, recorded_error(reason)})}
  end

  def handle_async(:fetch_recorded, {:exit, reason}, socket) do
    {:noreply, assign(socket, recorded_state: {:error, recorded_error(reason)})}
  end

  @impl Phoenix.LiveComponent
  def handle_event("load-recorded", _params, socket) do
    job = socket.assigns.job

    socket =
      socket
      |> assign(recorded_state: :loading)
      |> start_async(:fetch_recorded, fn -> Recorded.fetch(job) end)

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

  def handle_event("toggle-diagnostics", _params, socket) do
    {:noreply, assign(socket, :diagnostics_open?, not socket.assigns.diagnostics_open?)}
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

  def handle_event("form-change", params, socket) do
    form = Map.merge(socket.assigns.form, Form.cast_params(params))

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("discard-changes", _params, socket) do
    {:noreply, assign_seed(socket, socket.assigns.job)}
  end

  def handle_event("save-job", params, socket) do
    %{access: access, job: job} = socket.assigns

    if can?(:update_jobs, access) do
      form = Map.merge(socket.assigns.form, Form.cast_params(params))

      case Form.build_changes(form, job) do
        {:ok, changes} when map_size(changes) > 0 ->
          send(self(), {:update_job, job, changes})

          {:noreply, assign(socket, errors: [], form: form, invalid: [])}

        {:ok, _unchanged} ->
          {:noreply, assign_seed(socket, job)}

        {:error, failure} ->
          {:noreply,
           assign(socket,
             errors: Form.format_failure(failure),
             form: form,
             invalid: Form.invalid_fields(failure)
           )}
      end
    else
      {:noreply, socket}
    end
  end

  # Helpers

  defp format_args(job, resolver) do
    Resolver.call_with_fallback(resolver, :format_job_args, [job])
  end

  defp format_meta(%{meta: meta} = job, resolver) do
    job = %{job | meta: Map.drop(meta, @hidden_meta)}

    Resolver.call_with_fallback(resolver, :format_job_meta, [job])
  end

  defp format_recorded(payload, job, resolver) do
    {:ok, Resolver.call_with_fallback(resolver, :format_recorded, [payload, job])}
  end

  defp recorded_output({:ok, output}), do: output
  defp recorded_output(_state), do: nil

  defp recorded_message({:error, :disabled}), do: "Recording isn't enabled for this worker"
  defp recorded_message({:error, :none}), do: "No output recorded yet"
  defp recorded_message({:error, :missing}), do: "Stored output is no longer available"
  defp recorded_message({:error, :timeout}), do: "Timed out fetching output"
  defp recorded_message({:error, :backend}), do: "Unable to reach the storage backend"
  defp recorded_message({:error, :too_large}), do: "Output is too large to display"
  defp recorded_message(:idle), do: "Stored externally"
  defp recorded_message(_state), do: nil

  # Backend failures may carry signed URLs or credentials, so the reason is never rendered.
  defp recorded_error(reason) when reason in ~w(none missing timeout)a, do: reason
  defp recorded_error(_reason), do: :backend

  defp loadable?(job, state) do
    Recorded.status(job) == :external and
      state in [:idle, {:error, :missing}, {:error, :timeout}, {:error, :backend}]
  end

  defp size_limit(resolver) do
    Resolver.call_with_fallback(resolver, :recorded_size_limit, [])
  end

  defp oversized?(_size, :infinity), do: false
  defp oversized?(size, limit), do: is_integer(size) and size > limit

  defp format_signal(%{meta: %{"signal" => value}} = job, resolver) do
    Resolver.call_with_fallback(resolver, :format_signal, [value, job])
  end

  defp format_signal(%{meta: %{"wait_until" => wait_until}}, _resolver) do
    case wait_until_to_datetime(wait_until) do
      {:ok, datetime} -> "Deadline #{Timing.datetime_to_words(datetime)}"
      :infinity -> "No deadline"
      :error -> ""
    end
  end

  defp signal_status(%{meta: %{"signal" => _}}), do: :received
  defp signal_status(%{meta: %{"wait_until" => _}}), do: :awaiting
  defp signal_status(_), do: :none

  defp signal_heading(job) do
    case signal_status(job) do
      :received -> "Received Signal"
      :awaiting -> "Awaiting Signal"
      :none -> "Signal"
    end
  end

  defp wait_until_to_datetime("infinity"), do: :infinity

  defp wait_until_to_datetime(ms) when is_integer(ms) do
    case DateTime.from_unix(ms, :millisecond) do
      {:ok, datetime} -> {:ok, datetime |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)}
      _ -> :error
    end
  end

  defp wait_until_to_datetime(_), do: :error

  defp error_entry(assigns) do
    error =
      assigns.errors
      |> Enum.sort_by(& &1["attempt"], assigns.sort)
      |> Enum.at(assigns.index)

    {message, stacktrace} = parse_error(error["error"])

    assigns = assign(assigns, error: error, message: message, stacktrace: stacktrace)

    ~H"""
    <div class="p-4 bg-gray-50 dark:bg-gray-800 rounded-md">
      <div class="flex items-center justify-between mb-3 text-sm text-gray-500 dark:text-gray-400 tabular">
        <span>Attempt {@error["attempt"]}</span>
        <span>
          {Timing.datetime_to_words(@error["at"])}
          <span class="text-gray-400 dark:text-gray-500">({@error["at"]})</span>
        </span>
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
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#errors-toggle")
    |> JS.add_class("rotate-90", to: "#errors-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#errors-chevron.rotate-90")
  end

  defp toggle_job_data do
    %JS{}
    |> JS.toggle(to: "#job-data-content", in: "fade-in-scale", out: "fade-out-scale")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#job-data-toggle")
    |> JS.add_class("rotate-90", to: "#job-data-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#job-data-chevron.rotate-90")
  end

  defp job_title(job), do: Map.get(job.meta, "decorated_name", job.worker)

  defp workflow_display_name(job) do
    job.meta["workflow_name"] || job.meta["workflow_id"]
  end

  defp toggle_edit do
    %JS{}
    |> JS.toggle(to: "#edit-content", in: "fade-in-scale", out: "fade-out-scale")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#edit-toggle")
    |> JS.add_class("rotate-90", to: "#edit-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#edit-chevron.rotate-90")
  end

  defp scroll_to_edit do
    %JS{}
    |> JS.show(to: "#edit-content", transition: "fade-in-scale")
    |> JS.set_attribute({"aria-expanded", "true"}, to: "#edit-toggle")
    |> JS.add_class("rotate-90", to: "#edit-chevron")
    |> JS.focus(to: "#job-edit-form input")
  end

  defp copy_to_clipboard(text) do
    JS.dispatch("phx:copy-to-clipboard", detail: %{text: text})
  end

  defp executing?(%{state: state}), do: state == "executing"

  defp retry_tooltip(job) do
    cond do
      runnable?(job) or retryable?(job) -> "Retry this job"
      executing?(job) -> "Executing jobs can't be retried"
      true -> "This job is already waiting to run"
    end
  end

  defp format_bytes(nil), do: "—"
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1024 / 1024, 1)} MB"

  defp format_number(nil), do: "—"
  defp format_number(num) when is_integer(num), do: integer_to_delimited(num)

  defp format_status(nil), do: "—"
  defp format_status(status) when is_binary(status), do: String.capitalize(status)

  defp format_diagnostics_time(unix_time) when is_integer(unix_time) do
    unix_time
    |> DateTime.from_unix!()
    |> Calendar.strftime("%H:%M:%S")
  end

  defp parse_stacktrace(nil), do: []

  defp parse_stacktrace(stacktrace) when is_binary(stacktrace) do
    stacktrace
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
