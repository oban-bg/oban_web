defmodule Oban.Web.Workflows.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Components.Core
  alias Oban.Web.Timing
  alias Oban.Web.WorkflowQuery
  alias Oban.Web.Workflows.Helpers

  @states ~w(suspended available scheduled executing retryable completed cancelled discarded)a

  # States that Oban.Pro.Workflow.cancel_jobs/2 will actually cancel.
  @cancellable ~w(suspended available scheduled executing retryable)a

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    sub_workflows = assigns[:sub_workflows] || []

    socket =
      socket
      |> assign(assigns)
      |> assign(:sub_workflows, sub_workflows)
      |> assign_new(:workflow_id, fn -> nil end)
      |> assign_new(:graph_open?, fn -> true end)
      |> assign_new(:subs_open?, fn -> match?([_ | _], sub_workflows) end)
      |> assign_new(:graph_data, fn -> %{jobs: [], sub_workflows: []} end)
      |> assign_new(:compensation, fn -> nil end)
      |> assign_new(:compensation_status, fn -> :none end)
      |> assign_new(:compensation_steps, fn -> [] end)
      |> assign_new(:compensation_policy, fn -> [] end)
      |> assign_new(:origin_workflow, fn -> nil end)
      |> assign_new(:comp_open?, fn -> true end)
      |> push_graph_data()

    {:ok, socket}
  end

  defp push_graph_data(socket) do
    if socket.assigns[:graph_open?] do
      push_event(socket, "graph-data", socket.assigns.graph_data)
    else
      socket
    end
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="workflow-details">
      <%= if @workflow do %>
        <.header
          access={@access}
          myself={@myself}
          pro_available?={@pro_available?}
          workflow={@workflow}
          sub_workflows={@sub_workflows}
          compensation_status={@compensation_status}
        />

        <div class="grid grid-cols-6 gap-6 px-3 py-6">
          <div class="col-span-4">
            <.progress_bar workflow={@workflow} subs={@sub_workflows} />
          </div>

          <div class="col-span-2 min-w-0">
            <.stats_grid
              workflow={@workflow}
              sub_workflows={@sub_workflows}
              parent_workflow={@parent_workflow}
              origin_workflow={@origin_workflow}
            />
          </div>
        </div>

        <.graph_section myself={@myself} graph_open?={@graph_open?} graph_data={@graph_data} />

        <.compensation_section
          :if={@compensation_status != :none}
          access={@access}
          comp_open?={@comp_open?}
          compensation={@compensation}
          myself={@myself}
          pro_available?={@pro_available?}
          policy={@compensation_policy}
          status={@compensation_status}
          steps={@compensation_steps}
          workflow={@workflow}
        />

        <.sub_workflows_section
          myself={@myself}
          subs_open?={@subs_open?}
          sub_workflows={@sub_workflows}
        />
      <% else %>
        <.not_found workflow_id={@workflow_id} />
      <% end %>
    </div>
    """
  end

  attr :workflow_id, :string, default: nil

  defp not_found(assigns) do
    ~H"""
    <div id="workflow-not-found" class="flex flex-col items-center justify-center py-16 text-center">
      <Icons.icon name="icon-rectangle-group" class="h-12 w-12 text-gray-400 dark:text-gray-500" />
      <h2 class="mt-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
        Workflow not found
      </h2>
      <p class="mt-2 max-w-md text-sm text-gray-500 dark:text-gray-400">
        <%= if @workflow_id do %>
          No workflow matches <span class="font-mono break-all">{@workflow_id}</span>. Its jobs may
          have been pruned, or the ID may be mistyped.
        <% else %>
          Its jobs may have been pruned, or the ID may be mistyped.
        <% end %>
      </p>
      <.link
        id="not-found-back"
        navigate={oban_path(:workflows)}
        class="mt-4 inline-flex items-center rounded text-sm font-medium text-violet-600 hover:text-violet-500 dark:text-violet-400 dark:hover:text-violet-300 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
      >
        <Icons.icon name="icon-arrow-left" class="w-4 h-4 mr-1.5" /> Back to workflows
      </.link>
    </div>
    """
  end

  # Header

  attr :access, :any, required: true
  attr :myself, :any, required: true
  attr :pro_available?, :boolean, required: true
  attr :workflow, :map, required: true
  attr :sub_workflows, :list, required: true
  attr :compensation_status, :atom, required: true

  defp header(assigns) do
    cancellable = cancellable_count(assigns.workflow, assigns.sub_workflows)
    retryable = retryable_count(assigns.workflow, assigns.sub_workflows)

    assigns = assign(assigns, cancellable: cancellable, retryable: retryable)

    ~H"""
    <div class="flex justify-between items-center gap-6 px-3 py-4 border-b border-gray-200 dark:border-gray-700">
      <div class="flex items-center min-w-0">
        <h2 class="min-w-0">
          <button
            id="back-link"
            class="flex items-center min-w-0 max-w-full hover:text-blue-500 cursor-pointer bg-transparent border-0 p-0 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
            data-escape-back={true}
            phx-hook="HistoryBack"
            type="button"
          >
            <Icons.icon name="icon-arrow-left" class="w-5 h-5 shrink-0" />
            <span class="text-lg font-bold ml-2 truncate">
              {Helpers.display_name(@workflow)}
              <span class="font-normal text-gray-500 dark:text-gray-400">Workflow</span>
            </span>
          </button>
        </h2>
      </div>

      <div class="flex shrink-0 items-center space-x-3">
        <Core.status_badge
          :if={Helpers.compensation?(@workflow)}
          id="status-compensation"
          icon="arrow_path_rounded"
          label="Compensation"
          tooltip="Rolls back the completed steps of the workflow it compensates"
        />

        <.state_badge workflow={@workflow} />

        <Core.icon_button
          id="detail-cancel"
          icon="x_circle"
          label="Cancel"
          color="red"
          tooltip={cancel_tooltip(@pro_available?)}
          confirm={cancel_confirm(@workflow, @cancellable, @sub_workflows)}
          disabled={not @pro_available? or not can?(:cancel_workflows, @access) or @cancellable == 0}
          phx-target={@myself}
          phx-click="cancel-workflow"
        />

        <Core.icon_button
          id="detail-retry"
          icon="arrow_path"
          label="Retry"
          color="blue"
          tooltip={retry_tooltip(@pro_available?)}
          confirm={retry_confirm(@workflow, @compensation_status)}
          disabled={not @pro_available? or not can?(:retry_workflows, @access) or @retryable == 0}
          phx-target={@myself}
          phx-click="retry-workflow"
        />
      </div>
    </div>
    """
  end

  attr :workflow, :map, required: true

  defp state_badge(assigns) do
    {icon, color, label, tooltip} =
      case assigns.workflow.state do
        "executing" ->
          {"play_circle", "emerald", "Executing", "Jobs are still running"}

        "completed" ->
          {"check_circle", "cyan", "Completed", "Every job finished successfully"}

        "cancelled" ->
          {"x_circle", "violet", "Cancelled", "Jobs were cancelled"}

        "discarded" ->
          {"exclamation_circle", "rose", "Discarded", "At least one job was discarded"}

        state ->
          {"minus_circle", "gray", String.capitalize(state || "unknown"), nil}
      end

    assigns = assign(assigns, icon: icon, color: color, label: label, tooltip: tooltip)

    ~H"""
    <Core.status_badge
      id="status-state"
      icon={@icon}
      color={@color}
      label={@label}
      tooltip={@tooltip}
    />
    """
  end

  # Progress Bar

  attr :workflow, :map, required: true
  attr :subs, :list, default: []

  defp progress_bar(assigns) do
    wf = assigns.workflow
    sub = count_sub_states(assigns.subs)

    total = Enum.reduce(@states, 0, &(Map.fetch!(wf, &1) + &2)) + length(assigns.subs)
    completed = wf.completed + sub.completed

    states = [
      {:suspended, wf.suspended + sub.suspended, "bg-gray-400", "Suspended"},
      {:scheduled, wf.scheduled + sub.scheduled, "bg-indigo-400", "Scheduled"},
      {:available, wf.available + sub.available, "bg-blue-400", "Available"},
      {:retryable, wf.retryable + sub.retryable, "bg-yellow-400", "Retryable"},
      {:executing, wf.executing + sub.executing, "bg-emerald-400", "Executing"},
      {:completed, completed, "bg-cyan-400", "Completed"},
      {:cancelled, wf.cancelled + sub.cancelled, "bg-violet-400", "Cancelled"},
      {:discarded, wf.discarded + sub.discarded, "bg-rose-400", "Discarded"}
    ]

    percent = if total > 0, do: round(completed / total * 100), else: 0

    assigns =
      assign(assigns, states: states, total: total, completed: completed, percent: percent)

    ~H"""
    <div class="bg-gray-50 dark:bg-gray-800 rounded-md p-4" id="workflow-progress">
      <div class="flex items-center justify-between mb-3">
        <span class="text-base font-semibold text-gray-700 dark:text-gray-200 tabular">
          {@percent}% Complete
        </span>
        <span class="text-base text-gray-500 dark:text-gray-400 tabular">
          {@completed}/{@total} jobs
        </span>
      </div>

      <div
        class="h-3 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden flex"
        role="progressbar"
        aria-valuemin="0"
        aria-valuemax="100"
        aria-valuenow={@percent}
        aria-label={"#{@completed} of #{@total} jobs complete"}
      >
        <%= for {_state, count, color, _label} <- @states, count > 0 do %>
          <div class={["h-full", color]} style={"width: #{count / max(@total, 1) * 100}%"} />
        <% end %>
      </div>

      <ul class="flex flex-wrap gap-x-4 gap-y-1.5 mt-3">
        <li
          :for={{state, count, color, label} <- @states}
          id={"legend-#{state}"}
          class={[
            "flex items-center text-sm",
            if(count == 0,
              do: "text-gray-500 dark:text-gray-400",
              else: "text-gray-600 dark:text-gray-400"
            )
          ]}
        >
          <span class={[
            "w-2.5 h-2.5 rounded-full shrink-0 mr-1.5",
            color,
            count == 0 && "opacity-40"
          ]} />
          <span>{label}</span>
          <span class={[
            "ml-1 tabular",
            count > 0 && "font-medium text-gray-700 dark:text-gray-300"
          ]}>
            {count}
          </span>
        </li>
      </ul>
    </div>
    """
  end

  # Stats Grid

  attr :workflow, :any, required: true
  attr :sub_workflows, :list, required: true
  attr :parent_workflow, :map, default: nil
  attr :origin_workflow, :map, default: nil

  defp stats_grid(assigns) do
    queues = Map.get(assigns.workflow.meta || %{}, "queues", [])
    assigns = assign(assigns, queues: queues)

    ~H"""
    <dl
      id="workflow-stats"
      class="grid grid-cols-4 gap-x-4 gap-y-4 h-full p-3 bg-gray-50 dark:bg-gray-800 rounded-md"
    >
      <div class="flex flex-col col-span-4 min-w-0">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Workflow ID
        </dt>
        <dd class="text-base text-gray-800 dark:text-gray-200 font-mono break-all">
          {@workflow.id}
        </dd>
      </div>

      <div class="flex flex-col">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Started
        </dt>
        <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
          <.format_started_at workflow={@workflow} />
        </dd>
      </div>

      <div class="flex flex-col">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Duration
        </dt>
        <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
          <.format_duration workflow={@workflow} />
        </dd>
      </div>

      <div class="flex flex-col col-span-2">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Sub-workflows
        </dt>
        <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
          {length(@sub_workflows)}
        </dd>
      </div>

      <div class="flex flex-col col-span-4 min-w-0">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Queues
        </dt>
        <dd class="flex flex-wrap items-center gap-1.5">
          <span :if={@queues == []} class="text-base text-gray-500 dark:text-gray-400">—</span>
          <span
            :for={queue <- @queues}
            class="inline-flex items-center px-1.5 py-0.5 rounded text-sm bg-gray-200/70 text-gray-700 dark:bg-gray-700 dark:text-gray-300"
          >
            {queue}
          </span>
        </dd>
      </div>

      <div :if={@parent_workflow} class="flex flex-col col-span-4 min-w-0">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Parent Workflow
        </dt>
        <dd>
          <.related_link
            id="parent-link"
            icon="icon-rectangle-group"
            navigate={oban_path([:workflows, @parent_workflow.id])}
            tooltip="View the workflow this one belongs to"
          >
            {@parent_workflow.name || @parent_workflow.id}
          </.related_link>
        </dd>
      </div>

      <div :if={@origin_workflow} class="flex flex-col col-span-4 min-w-0">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Rolls Back
        </dt>
        <dd>
          <.related_link
            id="origin-link"
            icon="icon-arrow-path-rounded"
            navigate={oban_path([:workflows, @origin_workflow.id])}
            tooltip="View the workflow this one compensates"
          >
            {Helpers.display_name(@origin_workflow)}
          </.related_link>
        </dd>
      </div>
    </dl>
    """
  end

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :navigate, :string, required: true
  attr :tooltip, :string, required: true
  slot :inner_block, required: true

  defp related_link(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@navigate}
      class="inline-flex items-center max-w-full text-base text-gray-800 dark:text-gray-200 hover:text-blue-500 dark:hover:text-blue-400 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
      data-title={@tooltip}
      phx-hook="Tippy"
    >
      <Icons.icon name={@icon} class="w-4 h-4 mr-1.5 shrink-0 text-violet-500" />
      <span class="truncate">{render_slot(@inner_block)}</span>
    </.link>
    """
  end

  attr :workflow, :any, required: true

  defp format_started_at(assigns) do
    wf = assigns.workflow
    executed? = wf.executing + wf.completed > 0
    started = if executed?, do: wf.started_at
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
    <span :if={is_nil(@started)} class="text-gray-500 dark:text-gray-400">Not started</span>
    """
  end

  attr :workflow, :any, required: true

  defp format_duration(assigns) do
    wf = assigns.workflow
    executing? = wf.state == "executing"
    started? = not is_nil(wf.started_at)

    duration =
      if wf.started_at && wf.completed_at do
        DateTime.diff(wf.completed_at, wf.started_at, :millisecond)
      end

    formatted =
      if is_nil(duration) or duration <= 0 do
        "—"
      else
        duration |> div(1000) |> Timing.to_duration()
      end

    assigns =
      assign(assigns,
        executing?: executing?,
        started?: started?,
        formatted: formatted,
        started_at: wf.started_at
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

  # Graph Section

  attr :myself, :any, required: true
  attr :graph_open?, :boolean, required: true
  attr :graph_data, :map, required: true

  defp graph_section(assigns) do
    ~H"""
    <section class="border-t border-gray-200 dark:border-gray-700">
      <div class="px-3 py-6">
        <.section_toggle
          id="graph-toggle"
          controls="workflow-graph"
          open?={@graph_open?}
          click="toggle-graph"
          myself={@myself}
        >
          Workflow Graph
        </.section_toggle>

        <div :if={@graph_open?} class="mt-3">
          <div
            id="workflow-graph"
            class="relative h-96 rounded-md overflow-hidden shadow-inner workflow-graph-canvas"
            phx-hook="WorkflowGraph"
            phx-target={@myself}
            phx-update="ignore"
          >
            <svg
              class="w-full h-full text-gray-400 dark:text-gray-500"
              role="group"
              aria-label="Workflow graph. Each step is a button that opens the job."
            >
              <text
                x="50%"
                y="50%"
                text-anchor="middle"
                dominant-baseline="middle"
                fill="currentColor"
                font-size="14"
              >
                Loading workflow graph…
              </text>
            </svg>

            <div
              id="truncation-warning"
              class="hidden absolute top-3 left-3 right-3 items-center gap-2 px-3 py-2 rounded-md text-sm border bg-amber-50 text-amber-800 border-amber-200 dark:bg-amber-900/20 dark:text-amber-300 dark:border-amber-700"
              role="status"
            >
              <Icons.icon name="icon-exclamation-circle" class="w-4 h-4 shrink-0" />
              <span>
                Showing the first <span data-job-count class="tabular">0</span>
                jobs. This workflow has more jobs than the graph can display.
              </span>
            </div>

            <div id="graph-controls" class="absolute bottom-3 right-3 flex flex-col gap-1">
              <.graph_control id="zoom-in" icon="icon-magnifying-glass-plus" label="Zoom in" />
              <.graph_control id="zoom-out" icon="icon-magnifying-glass-minus" label="Zoom out" />
              <.graph_control id="reset-view" icon="icon-arrows-pointing-in" label="Reset view" />
              <.graph_control
                id="toggle-tracking"
                icon="icon-viewfinder-circle"
                label="Follow the active step"
                pressed
              />
              <.graph_control id="toggle-direction" label="Lay out top to bottom">
                <Icons.icon name="icon-arrows-right-left" class="w-5 h-5" data-direction="LR" />
                <Icons.icon name="icon-arrows-up-down" class="w-5 h-5 hidden" data-direction="TB" />
              </.graph_control>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, default: nil
  attr :pressed, :boolean, default: nil
  slot :inner_block

  defp graph_control(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      title={@label}
      aria-label={@label}
      aria-pressed={if is_boolean(@pressed), do: to_string(@pressed)}
      class="w-8 h-8 flex items-center justify-center rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 aria-pressed:text-blue-500 aria-pressed:bg-gray-100 dark:aria-pressed:bg-gray-700"
    >
      <Icons.icon :if={@icon} name={@icon} class="w-5 h-5" />
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :id, :string, required: true
  attr :controls, :string, required: true
  attr :open?, :boolean, required: true
  attr :click, :string, required: true
  attr :myself, :any, required: true
  slot :inner_block, required: true
  slot :aside

  defp section_toggle(assigns) do
    ~H"""
    <h3>
      <button
        id={@id}
        type="button"
        aria-expanded={to_string(@open?)}
        aria-controls={@controls}
        class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
        phx-click={@click}
        phx-target={@myself}
      >
        <Icons.icon
          name="icon-chevron-right"
          class={["w-5 h-5 transition-transform", @open? && "rotate-90"]}
        />
        <span class="font-semibold">{render_slot(@inner_block)}</span>
        {render_slot(@aside)}
      </button>
    </h3>
    """
  end

  # Compensation Section

  attr :access, :any, required: true
  attr :comp_open?, :boolean, required: true
  attr :compensation, :map, default: nil
  attr :myself, :any, required: true
  attr :policy, :list, default: []
  attr :pro_available?, :boolean, required: true
  attr :status, :atom, required: true
  attr :steps, :list, default: []
  attr :workflow, :map, required: true

  defp compensation_section(assigns) do
    ~H"""
    <section class="border-t border-gray-200 dark:border-gray-700">
      <div class="px-3 py-6">
        <.section_toggle
          id="comp-toggle"
          controls="compensation-detail"
          open?={@comp_open?}
          click="toggle-comp"
          myself={@myself}
        >
          Compensation
          <:aside>
            <.compensation_badge status={@status} policy={@policy} />
          </:aside>
        </.section_toggle>

        <div :if={@comp_open?} class="mt-3" id="compensation-detail">
          <div class="flex items-center justify-between px-2 pb-3">
            <div class="flex items-center gap-1.5">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
                Triggers On
              </span>
              <span
                :for={state <- @policy}
                class="inline-flex items-center px-1.5 py-0.5 rounded text-sm bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300"
              >
                {state}
              </span>
            </div>

            <div class="flex items-center space-x-3">
              <.link
                :if={@compensation}
                id="compensation-link"
                navigate={oban_path([:workflows, @compensation.id])}
                class="inline-flex items-center rounded text-sm font-medium text-violet-600 hover:text-violet-500 dark:text-violet-400 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
              >
                View Workflow
              </.link>

              <Core.icon_button
                :if={@compensation}
                id="comp-cancel"
                icon="x_circle"
                label="Cancel"
                color="red"
                tooltip="Cancel the remaining rollback steps"
                confirm={"Cancel the rollback for #{Helpers.display_name(@workflow)}? Steps that haven't rolled back yet will stay as they are."}
                disabled={
                  not @pro_available? or not can?(:cancel_workflows, @access) or
                    @status != :executing
                }
                phx-target={@myself}
                phx-click="cancel-compensation"
              />

              <Core.icon_button
                :if={@compensation}
                id="comp-retry"
                icon="arrow_path"
                label="Retry"
                color="blue"
                tooltip="Retry the rollback"
                confirm={"Retry the rollback for #{Helpers.display_name(@workflow)}? Rollback steps that already completed will run again."}
                disabled={
                  not @pro_available? or not can?(:retry_workflows, @access) or
                    @status != :failed
                }
                phx-target={@myself}
                phx-click="retry-compensation"
              />
            </div>
          </div>

          <table :if={Enum.any?(@steps)} class="min-w-full">
            <thead>
              <tr class="border-b border-gray-200 dark:border-gray-700 text-gray-500 dark:text-gray-400">
                <th
                  scope="col"
                  class="px-2 py-1.5 text-left text-xs font-medium uppercase tracking-wider"
                >
                  Step
                </th>
                <th
                  scope="col"
                  class="px-2 py-1.5 text-left text-xs font-medium uppercase tracking-wider"
                >
                  Rolls Back
                </th>
                <th
                  scope="col"
                  class="px-2 py-1.5 text-right text-xs font-medium uppercase tracking-wider"
                >
                  Attempt
                </th>
                <th
                  scope="col"
                  class="px-2 py-1.5 text-center text-xs font-medium uppercase tracking-wider"
                >
                  Status
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
              <.compensation_step_row :for={step <- @steps} step={step} />
            </tbody>
          </table>
        </div>
      </div>
    </section>
    """
  end

  attr :step, :map, required: true

  defp compensation_step_row(assigns) do
    ~H"""
    <tr id={"comp-step-#{@step.id}"} class="hover:bg-gray-50 dark:hover:bg-gray-800/60">
      <td class="px-2 py-2.5 font-medium text-sm text-gray-700 dark:text-gray-300">
        <.link
          navigate={oban_path([:jobs, @step.id])}
          class="rounded hover:text-blue-500 dark:hover:text-blue-400 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
        >
          {@step.meta["origin_name"]}
        </.link>
      </td>
      <td class="px-2 py-2.5 text-sm text-gray-500 dark:text-gray-400">
        <.link
          :if={@step.meta["origin_job_id"]}
          navigate={oban_path([:jobs, @step.meta["origin_job_id"]])}
          class="rounded hover:text-blue-500 dark:hover:text-blue-400 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
        >
          {@step.meta["origin_worker"] || @step.meta["origin_job_id"]}
        </.link>
      </td>
      <td class="px-2 py-2.5 text-right text-sm text-gray-500 dark:text-gray-400 tabular">
        {@step.attempt}/{@step.max_attempts}
      </td>
      <td class="px-2 py-2.5 text-center">
        <.status_icon id={"comp-step-#{@step.id}"} state={@step.state} />
      </td>
    </tr>
    """
  end

  attr :status, :atom, required: true
  attr :policy, :list, default: []

  defp compensation_badge(assigns) do
    ~H"""
    <span
      id="comp-status"
      class={[
        "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
        compensation_badge_class(@status)
      ]}
      data-title={Helpers.compensation_description(@status, @policy)}
      phx-hook="Tippy"
    >
      {Helpers.compensation_label(@status)}
    </span>
    """
  end

  defp compensation_badge_class(:executing) do
    "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/20 dark:text-emerald-300"
  end

  defp compensation_badge_class(:completed) do
    "bg-cyan-100 text-cyan-700 dark:bg-cyan-500/20 dark:text-cyan-300"
  end

  defp compensation_badge_class(:failed) do
    "bg-rose-100 text-rose-700 dark:bg-rose-500/20 dark:text-rose-300"
  end

  defp compensation_badge_class(:pending) do
    "bg-yellow-100 text-yellow-700 dark:bg-yellow-500/20 dark:text-yellow-300"
  end

  defp compensation_badge_class(_status) do
    "bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-300"
  end

  # Sub-workflows Section

  attr :myself, :any, required: true
  attr :subs_open?, :boolean, required: true
  attr :sub_workflows, :list, required: true

  defp sub_workflows_section(assigns) do
    subs_count = length(assigns.sub_workflows)
    assigns = assign(assigns, subs_count: subs_count)

    ~H"""
    <section class="border-t border-gray-200 dark:border-gray-700">
      <div class="px-3 py-6">
        <.section_toggle
          :if={@subs_count > 0}
          id="subs-toggle"
          controls="sub-workflows"
          open?={@subs_open?}
          click="toggle-subs"
          myself={@myself}
        >
          Sub-workflows
          <span class="font-normal text-gray-500 dark:text-gray-400 tabular">({@subs_count})</span>
        </.section_toggle>

        <h3
          :if={@subs_count == 0}
          id="subs-none"
          class="flex items-center space-x-2 px-2 py-1.5 text-gray-600 dark:text-gray-300"
        >
          <span class="w-5 h-5 shrink-0" />
          <span class="font-semibold">Sub-workflows</span>
          <span class="font-normal text-gray-500 dark:text-gray-400">none</span>
        </h3>

        <div :if={@subs_open? and @subs_count > 0} class="mt-3" id="sub-workflows">
          <div class="flex items-center border-b border-gray-200 dark:border-gray-700 text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
            <span class="flex-1 px-2 py-1.5">Name</span>
            <span class="w-72 px-2 py-1.5">ID</span>
            <span class="w-40 px-2 py-1.5">Progress</span>
            <span class="w-24 px-2 py-1.5 text-right">Started</span>
            <span class="w-24 px-2 py-1.5 text-right">Duration</span>
            <span class="w-16 px-2 py-1.5 text-center">Status</span>
          </div>

          <ul class="divide-y divide-gray-100 dark:divide-gray-800">
            <.sub_workflow_row :for={sub <- @sub_workflows} workflow={sub} />
          </ul>
        </div>
      </div>
    </section>
    """
  end

  attr :workflow, :any, required: true

  defp sub_workflow_row(assigns) do
    wf = assigns.workflow
    total = Enum.reduce(@states, 0, &(Map.fetch!(wf, &1) + &2))
    percent = if total > 0, do: round(wf.completed / total * 100), else: 0

    assigns =
      assign(assigns,
        completed: wf.completed,
        total: total,
        percent: percent,
        state: wf.state
      )

    ~H"""
    <li id={"sub-workflow-#{@workflow.id}"}>
      <.link
        navigate={oban_path([:workflows, @workflow.id])}
        class="flex items-center rounded hover:bg-gray-50 dark:hover:bg-gray-800/60 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
      >
        <span class="flex-1 min-w-0 px-2 py-2.5 font-medium text-sm text-gray-700 dark:text-gray-300 truncate">
          {@workflow.name || @workflow.id}
        </span>
        <span class="w-72 px-2 py-2.5 text-sm text-gray-500 dark:text-gray-400 font-mono truncate">
          {@workflow.id}
        </span>
        <span class="w-40 px-2 py-2.5 flex items-center">
          <span class="w-20 h-1.5 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden mr-2">
            <span class="block h-full rounded-full bg-cyan-400" style={"width: #{@percent}%"} />
          </span>
          <span class="text-sm text-gray-500 dark:text-gray-400 tabular">
            {@completed}/{@total}
          </span>
        </span>
        <span class="w-24 px-2 py-2.5 text-right text-sm text-gray-500 dark:text-gray-400 tabular">
          <.format_started_at workflow={@workflow} />
        </span>
        <span class="w-24 px-2 py-2.5 text-right text-sm text-gray-500 dark:text-gray-400 tabular">
          <.format_duration workflow={@workflow} />
        </span>
        <span class="w-16 px-2 py-2.5 text-center">
          <.status_icon id={"sub-workflow-#{@workflow.id}"} state={@state} />
        </span>
      </.link>
    </li>
    """
  end

  attr :id, :string, required: true
  attr :state, :string, default: nil

  defp status_icon(assigns) do
    ~H"""
    <span id={"#{@id}-state"} class="inline-flex" data-title={status_title(@state)} phx-hook="Tippy">
      <%= case @state do %>
        <% "executing" -> %>
          <Icons.icon name="icon-play-circle" class="w-5 h-5 text-emerald-400" />
        <% "completed" -> %>
          <Icons.icon name="icon-check-circle" class="w-5 h-5 text-cyan-400" />
        <% "retryable" -> %>
          <Icons.icon name="icon-arrow-path" class="w-5 h-5 text-yellow-400" />
        <% "cancelled" -> %>
          <Icons.icon name="icon-x-circle" class="w-5 h-5 text-violet-400" />
        <% "discarded" -> %>
          <Icons.icon name="icon-exclamation-circle" class="w-5 h-5 text-rose-400" />
        <% _ -> %>
          <Icons.icon name="icon-minus-circle" class="w-5 h-5 text-gray-400" />
      <% end %>
      <span class="sr-only">{status_title(@state)}</span>
    </span>
    """
  end

  defp status_title(state) when is_binary(state), do: String.capitalize(state)
  defp status_title(_state), do: "Unknown"

  # Event Handlers

  @impl Phoenix.LiveComponent
  def handle_event("cancel-workflow", _params, socket) do
    %{workflow: workflow} = socket.assigns

    send(self(), {:cancel_workflow, workflow.id, Helpers.display_name(workflow)})

    {:noreply, socket}
  end

  def handle_event("retry-workflow", _params, socket) do
    %{workflow: workflow} = socket.assigns

    send(self(), {:retry_workflow, workflow.id, Helpers.display_name(workflow)})

    {:noreply, socket}
  end

  def handle_event("toggle-graph", _params, socket) do
    graph_open? = not socket.assigns[:graph_open?]

    socket = assign(socket, :graph_open?, graph_open?)
    socket = if graph_open?, do: push_graph_data(socket), else: socket

    {:noreply, socket}
  end

  def handle_event("toggle-comp", _params, socket) do
    {:noreply, assign(socket, :comp_open?, not socket.assigns[:comp_open?])}
  end

  def handle_event("cancel-compensation", _params, socket) do
    %{compensation: compensation, workflow: workflow} = socket.assigns
    name = "the #{Helpers.display_name(workflow)} rollback"

    send(self(), {:cancel_workflow, compensation.id, name})

    {:noreply, socket}
  end

  def handle_event("retry-compensation", _params, socket) do
    %{compensation: compensation, workflow: workflow} = socket.assigns
    name = "the #{Helpers.display_name(workflow)} rollback"

    send(self(), {:retry_workflow, compensation.id, name})

    {:noreply, socket}
  end

  def handle_event("toggle-subs", _params, socket) do
    {:noreply, assign(socket, :subs_open?, not socket.assigns[:subs_open?])}
  end

  def handle_event("navigate-to-job", %{"job_id" => job_id}, socket) do
    {:noreply, push_navigate(socket, to: oban_path([:jobs, job_id]))}
  end

  def handle_event("navigate-to-workflow", %{"workflow_id" => workflow_id}, socket) do
    {:noreply, push_navigate(socket, to: oban_path([:workflows, workflow_id]))}
  end

  def handle_event("expand-sub-workflow", %{"workflow_id" => sub_workflow_id}, socket) do
    %{jobs: jobs, truncated: truncated} =
      WorkflowQuery.get_sub_workflow_jobs(socket.assigns.conf, sub_workflow_id)

    payload = %{workflow_id: sub_workflow_id, jobs: jobs, truncated: truncated}
    socket = push_event(socket, "sub-workflow-jobs", payload)

    {:noreply, socket}
  end

  # Helpers

  defp cancel_tooltip(true), do: "Cancel every unfinished job in this workflow"
  defp cancel_tooltip(false), do: "Cancel requires Oban Pro"

  defp retry_tooltip(true), do: "Run the workflow again from its finished steps"
  defp retry_tooltip(false), do: "Retry requires Oban Pro"

  defp cancel_confirm(workflow, count, sub_workflows) do
    jobs = count_phrase(count, "unfinished job")
    name = Helpers.display_name(workflow)

    scope =
      case sub_workflows do
        [] -> name
        subs -> "#{name} and its #{count_phrase(length(subs), "sub-workflow")}"
      end

    "Cancel #{jobs} in #{scope}? Cancelled jobs can be retried from this page."
  end

  defp retry_confirm(workflow, compensation_status) do
    name = Helpers.display_name(workflow)

    consequence =
      if compensation_status in [:executing, :completed] do
        "Its rollback already ran, so steps that were rolled back will run again."
      else
        "Every step that isn't running or waiting will run again, including completed ones."
      end

    "Retry #{name}? #{consequence}"
  end

  defp cancellable_count(workflow, sub_workflows) do
    [workflow | sub_workflows]
    |> Enum.map(fn wf -> Enum.reduce(@cancellable, 0, &(Map.fetch!(wf, &1) + &2)) end)
    |> Enum.sum()
  end

  defp retryable_count(workflow, sub_workflows) do
    [workflow | sub_workflows]
    |> Enum.map(fn wf -> wf.retryable + wf.discarded + wf.cancelled end)
    |> Enum.sum()
  end

  defp count_phrase(1, noun), do: "1 #{noun}"
  defp count_phrase(count, noun), do: "#{count} #{noun}s"

  defp count_sub_states(subs) do
    init = Map.new(@states, &{&1, 0})

    Enum.reduce(subs, init, fn sub, acc ->
      Map.update!(acc, String.to_existing_atom(sub.state), &(&1 + 1))
    end)
  end
end
