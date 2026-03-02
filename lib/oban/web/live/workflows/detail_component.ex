defmodule Oban.Web.Workflows.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Timing
  alias Oban.Web.Components.Core

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    has_subs? = map_size(assigns.workflow.subs) > 0

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:sub_workflows, fn -> [] end)
      |> assign_new(:graph_open?, fn -> true end)
      |> assign_new(:subs_open?, fn -> has_subs? end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="workflow-details">
      <.header
        access={@access}
        myself={@myself}
        workflow={@workflow}
        parent_workflow={@parent_workflow}
      />

      <div class="grid grid-cols-5 gap-6 px-3 py-6">
        <div class="col-span-3">
          <.progress_bar workflow={@workflow} />
        </div>

        <div class="col-span-2">
          <.stats_grid workflow={@workflow} />
        </div>
      </div>

      <.graph_section myself={@myself} graph_open?={@graph_open?} />

      <.sub_workflows_section
        myself={@myself}
        subs_open?={@subs_open?}
        sub_workflows={@sub_workflows}
        workflow={@workflow}
      />
    </div>
    """
  end

  # Header

  attr :access, :any, required: true
  attr :myself, :any, required: true
  attr :workflow, :map, required: true
  attr :parent_workflow, :map, default: nil

  defp header(assigns) do
    ~H"""
    <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
      <div class="flex items-center">
        <button
          id="back-link"
          class="flex items-center hover:text-blue-500 cursor-pointer bg-transparent border-0 p-0"
          data-escape-back={true}
          phx-hook="HistoryBack"
          type="button"
        >
          <Icons.arrow_left class="w-5 h-5" />
          <span class="text-lg font-bold ml-2">{@workflow.display_name}</span>
        </button>

        <.parent_breadcrumb :if={@parent_workflow} parent={@parent_workflow} />
      </div>

      <div class="flex space-x-3">
        <Core.icon_button
          id="detail-cancel"
          icon="x_circle"
          label="Cancel"
          color="yellow"
          tooltip="Cancel all jobs in this workflow"
          disabled={not can?(:cancel_jobs, @access) or @workflow.state in [:completed, :cancelled]}
          phx-target={@myself}
          phx-click="cancel-workflow"
        />

        <Core.icon_button
          id="detail-retry"
          icon="arrow_path"
          label="Retry"
          color="blue"
          tooltip="Retry failed jobs in this workflow"
          disabled={not can?(:retry_jobs, @access) or not has_retryable?(@workflow)}
          phx-target={@myself}
          phx-click="retry-workflow"
        />
      </div>
    </div>
    """
  end

  attr :parent, :map, required: true

  defp parent_breadcrumb(assigns) do
    ~H"""
    <div class="flex items-center ml-3 text-sm text-gray-500 dark:text-gray-400">
      <Icons.arrow_turn_down_right class="w-4 h-4 mr-1" />
      <span>sub-workflow of</span>
      <.link
        navigate={oban_path([:workflows, @parent.id])}
        class="ml-1 font-medium text-violet-600 hover:text-violet-500 dark:text-violet-400"
      >
        {@parent.display_name}
      </.link>
    </div>
    """
  end

  # Progress Bar

  attr :workflow, :map, required: true

  defp progress_bar(assigns) do
    counts = assigns.workflow.counts
    total = assigns.workflow.total

    states = [
      {:scheduled, Map.get(counts, :scheduled, 0), "bg-indigo-400", "Scheduled"},
      {:available, Map.get(counts, :available, 0), "bg-blue-400", "Available"},
      {:retryable, Map.get(counts, :retryable, 0), "bg-yellow-400", "Retryable"},
      {:executing, Map.get(counts, :executing, 0), "bg-emerald-400", "Executing"},
      {:completed, Map.get(counts, :completed, 0), "bg-cyan-400", "Completed"},
      {:cancelled, Map.get(counts, :cancelled, 0), "bg-violet-400", "Cancelled"},
      {:discarded, Map.get(counts, :discarded, 0), "bg-rose-400", "Discarded"}
    ]

    completed = Map.get(counts, :completed, 0)
    percent = if total > 0, do: round(completed / total * 100), else: 0

    assigns =
      assign(assigns, states: states, total: total, completed: completed, percent: percent)

    ~H"""
    <div class="bg-gray-50 dark:bg-gray-800 rounded-md p-4">
      <div class="flex items-center justify-between mb-3">
        <span class="text-lg font-semibold text-gray-700 dark:text-gray-200">
          {@percent}% Complete
        </span>
        <span class="text-sm text-gray-500 dark:text-gray-400 tabular">
          {@completed}/{@total} jobs
        </span>
      </div>

      <div class="h-3 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden flex">
        <%= for {_state, count, color, _label} <- @states, count > 0 do %>
          <div class={["h-full", color]} style={"width: #{count / max(@total, 1) * 100}%"} />
        <% end %>
      </div>

      <div class="flex justify-between mt-3">
        <%= for {_state, count, color, label} <- @states do %>
          <div class="flex items-center text-sm">
            <span class={["w-3 h-3 rounded-full mr-1.5", color]} />
            <span class="text-gray-600 dark:text-gray-400">
              {label}
            </span>
            <span class="ml-1 font-medium text-gray-700 dark:text-gray-300 tabular">
              {count}
            </span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Graph Section

  attr :myself, :any, required: true
  attr :graph_open?, :boolean, required: true

  defp graph_section(assigns) do
    ~H"""
    <div class="border-t border-gray-200 dark:border-gray-700">
      <div class="px-3 py-6">
        <button
          id="graph-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
          phx-click="toggle-graph"
          phx-target={@myself}
        >
          <Icons.chevron_right class={[
            "w-5 h-5 transition-transform",
            @graph_open? && "rotate-90"
          ]} />
          <span class="font-semibold">Workflow Graph</span>
        </button>

        <div :if={@graph_open?} class="mt-3">
          <div class="h-80 bg-gray-50 dark:bg-gray-800 rounded-md flex items-center justify-center">
            <div class="text-center text-gray-400 dark:text-gray-500">
              <Icons.rectangle_group class="w-12 h-12 mx-auto mb-3" />
              <p class="text-sm">Workflow graph coming soon</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Stats Grid

  attr :workflow, :map, required: true

  defp stats_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-md h-full">
      <div class="flex flex-col col-span-2">
        <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Workflow ID
        </span>
        <span class="text-base text-gray-800 dark:text-gray-200 font-mono">
          {@workflow.id}
        </span>
      </div>

      <div class="flex flex-col">
        <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Status
        </span>
        <span class="text-base text-gray-800 dark:text-gray-200 capitalize">
          {@workflow.state}
        </span>
      </div>

      <div class="flex flex-col">
        <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Started
        </span>
        <span class="text-base text-gray-800 dark:text-gray-200">
          <.format_started_at workflow={@workflow} />
        </span>
      </div>

      <div class="flex flex-col">
        <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Duration
        </span>
        <span class="text-base text-gray-800 dark:text-gray-200">
          <.format_duration workflow={@workflow} />
        </span>
      </div>

      <div class="flex flex-col">
        <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Sub-workflows
        </span>
        <span class="text-base text-gray-800 dark:text-gray-200 tabular">
          {map_size(@workflow.subs)}
        </span>
      </div>

      <div class="flex flex-col col-span-3">
        <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Queues
        </span>
        <div class="flex flex-wrap items-center gap-1.5">
          <span
            :for={queue <- @workflow.queues}
            class="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400"
          >
            {queue}
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :workflow, :map, required: true

  defp format_started_at(assigns) do
    counts = assigns.workflow.counts
    executed? = Map.get(counts, :executing, 0) + Map.get(counts, :completed, 0) > 0

    started =
      if executed? do
        assigns.workflow.started_at
      end

    assigns = assign(assigns, started: started)

    ~H"""
    <span
      :if={@started}
      id={"wf-detail-started-#{@workflow.id}"}
      data-timestamp={DateTime.to_unix(@started, :millisecond)}
      phx-hook="Relativize"
      phx-update="ignore"
    >
      -
    </span>
    <span :if={is_nil(@started)}>—</span>
    """
  end

  attr :workflow, :map, required: true

  defp format_duration(assigns) do
    workflow = assigns.workflow
    executing? = workflow.state == :executing
    started? = not is_nil(workflow.started_at)

    formatted =
      if is_nil(workflow.duration) or workflow.duration <= 0 do
        "—"
      else
        workflow.duration
        |> div(1000)
        |> Timing.to_duration()
      end

    assigns =
      assign(assigns,
        executing?: executing?,
        started?: started?,
        formatted: formatted,
        started_at: workflow.started_at
      )

    ~H"""
    <span
      :if={@executing? and @started?}
      id={"wf-detail-duration-#{@workflow.id}"}
      data-timestamp={DateTime.to_unix(@started_at, :millisecond)}
      data-relative-mode="duration"
      phx-hook="Relativize"
      phx-update="ignore"
    >
      -
    </span>
    <span :if={not (@executing? and @started?)}>
      {@formatted}
    </span>
    """
  end

  # Sub-workflows Section

  attr :myself, :any, required: true
  attr :subs_open?, :boolean, required: true
  attr :sub_workflows, :list, required: true
  attr :workflow, :map, required: true

  defp sub_workflows_section(assigns) do
    subs_count = map_size(assigns.workflow.subs)
    assigns = assign(assigns, subs_count: subs_count)

    ~H"""
    <div class="border-t border-gray-200 dark:border-gray-700">
      <div class="px-3 py-6">
        <button
          id="subs-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
          phx-click="toggle-subs"
          phx-target={@myself}
        >
          <Icons.chevron_right class={[
            "w-5 h-5 transition-transform",
            @subs_open? && "rotate-90"
          ]} />
          <span class="font-semibold">
            Sub-workflows
            <span class="text-gray-400 font-normal">
              ({@subs_count})
            </span>
          </span>
        </button>

        <div :if={@subs_open? and @subs_count > 0} class="mt-3">
          <div class="bg-gray-50 dark:bg-gray-800 rounded-md overflow-hidden border border-gray-200 dark:border-gray-700">
            <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead>
                <tr class="bg-gray-50 dark:bg-gray-950 text-gray-500 dark:text-gray-500">
                  <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider">
                    Name
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider">
                    Progress
                  </th>
                  <th class="px-3 py-2 text-right text-xs font-medium uppercase tracking-wider">
                    Duration
                  </th>
                  <th class="px-3 py-2 text-right text-xs font-medium uppercase tracking-wider">
                    Status
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100 dark:divide-gray-800 bg-white dark:bg-gray-900">
                <.sub_workflow_row :for={sub <- @sub_workflows} workflow={sub} />
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :workflow, :map, required: true

  defp sub_workflow_row(assigns) do
    completed = Map.get(assigns.workflow.counts, :completed, 0)
    total = assigns.workflow.total
    percent = if total > 0, do: round(completed / total * 100), else: 0

    assigns = assign(assigns, completed: completed, total: total, percent: percent)

    ~H"""
    <tr class="hover:bg-gray-100 dark:hover:bg-gray-700/50">
      <td class="px-3 py-3">
        <.link
          navigate={oban_path([:workflows, @workflow.id])}
          class="font-medium text-sm text-violet-600 hover:text-violet-500 dark:text-violet-400"
        >
          {@workflow.display_name}
        </.link>
      </td>
      <td class="px-3 py-3">
        <div class="flex items-center">
          <div class="w-24 h-1.5 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden mr-2">
            <div class="h-full rounded-full bg-cyan-400" style={"width: #{@percent}%"} />
          </div>
          <span class="text-sm text-gray-500 dark:text-gray-400 tabular">
            {@completed}/{@total}
          </span>
        </div>
      </td>
      <td class="px-3 py-3 text-right text-sm text-gray-500 dark:text-gray-400">
        <.format_duration workflow={@workflow} />
      </td>
      <td class="px-3 py-3 text-right">
        <.status_icon state={@workflow.state} />
      </td>
    </tr>
    """
  end

  attr :state, :atom, required: true

  defp status_icon(assigns) do
    ~H"""
    <%= case @state do %>
      <% :executing -> %>
        <Icons.play_circle class="w-5 h-5 text-emerald-400 inline" />
      <% :completed -> %>
        <Icons.check_circle class="w-5 h-5 text-cyan-400 inline" />
      <% :cancelled -> %>
        <Icons.x_circle class="w-5 h-5 text-violet-400 inline" />
      <% :discarded -> %>
        <Icons.exclamation_circle class="w-5 h-5 text-rose-400 inline" />
      <% _ -> %>
        <Icons.minus_circle class="w-5 h-5 text-gray-400 inline" />
    <% end %>
    """
  end

  # Event Handlers

  @impl Phoenix.LiveComponent
  def handle_event("cancel-workflow", _params, socket) do
    send(self(), {:cancel_workflow, socket.assigns.workflow.id})

    {:noreply, socket}
  end

  def handle_event("retry-workflow", _params, socket) do
    send(self(), {:retry_workflow, socket.assigns.workflow.id})

    {:noreply, socket}
  end

  def handle_event("toggle-graph", _params, socket) do
    {:noreply, assign(socket, :graph_open?, not socket.assigns[:graph_open?])}
  end

  def handle_event("toggle-subs", _params, socket) do
    {:noreply, assign(socket, :subs_open?, not socket.assigns[:subs_open?])}
  end

  # Helpers

  defp has_retryable?(workflow) do
    counts = workflow.counts

    Map.get(counts, :retryable, 0) + Map.get(counts, :discarded, 0) +
      Map.get(counts, :cancelled, 0) > 0
  end
end
