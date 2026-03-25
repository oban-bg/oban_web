defmodule Oban.Web.Workflows.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Components.Core
  alias Oban.Web.Timing
  alias Oban.Web.WorkflowQuery

  @states ~w(suspended available scheduled executing retryable completed cancelled discarded)a

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    sub_workflows = assigns[:sub_workflows] || []

    socket =
      socket
      |> assign(assigns)
      |> assign(:sub_workflows, sub_workflows)
      |> assign_new(:graph_open?, fn -> true end)
      |> assign_new(:subs_open?, fn -> match?([_ | _], sub_workflows) end)
      |> assign_new(:graph_data, fn -> %{jobs: [], sub_workflows: []} end)
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
          parent_workflow={@parent_workflow}
        />

        <div class="grid grid-cols-6 gap-6 px-3 py-6">
          <div class="col-span-4">
            <.progress_bar workflow={@workflow} subs={@sub_workflows} />
          </div>

          <div class="col-span-2">
            <.stats_grid workflow={@workflow} sub_workflows={@sub_workflows} />
          </div>
        </div>

        <.graph_section myself={@myself} graph_open?={@graph_open?} graph_data={@graph_data} />

        <.sub_workflows_section
          myself={@myself}
          subs_open?={@subs_open?}
          sub_workflows={@sub_workflows}
        />
      <% else %>
        <div class="flex items-center justify-center py-16">
          <div class="text-center">
            <Icons.rectangle_group class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" />
            <h3 class="mt-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
              Workflow not found
            </h3>
            <p class="mt-2 text-base text-gray-500 dark:text-gray-400">
              This workflow may have been deleted or doesn't exist.
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Header

  attr :access, :any, required: true
  attr :myself, :any, required: true
  attr :pro_available?, :boolean, required: true
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
          <span class="text-lg font-bold ml-2">{@workflow.name || @workflow.id}</span>
        </button>

        <.parent_breadcrumb :if={@parent_workflow} parent={@parent_workflow} />
      </div>

      <div class="flex space-x-3">
        <Core.icon_button
          id="detail-cancel"
          icon="x_circle"
          label="Cancel"
          color="yellow"
          tooltip={cancel_tooltip(@pro_available?)}
          disabled={
            not @pro_available? or not can?(:cancel_workflows, @access) or
              @workflow.state in ~w(completed cancelled)
          }
          phx-target={@myself}
          phx-click="cancel-workflow"
        />

        <Core.icon_button
          id="detail-retry"
          icon="arrow_path"
          label="Retry"
          color="blue"
          tooltip={retry_tooltip(@pro_available?)}
          disabled={
            not @pro_available? or not can?(:retry_workflows, @access) or
              not has_retryable?(@workflow)
          }
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
        {@parent.name || @parent.id}
      </.link>
    </div>
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
        <span class="text-base font-semibold text-gray-700 dark:text-gray-200">
          {@percent}% Complete
        </span>
        <span class="text-base text-gray-500 dark:text-gray-400 tabular">
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
          <div class="group flex items-center text-sm px-2 py-1 -mx-2 -my-1 rounded-full hover:bg-white dark:hover:bg-white/20 transition-all duration-200 cursor-default">
            <span class={["w-3 h-3 rounded-full shrink-0 mr-1.5", color]} />
            <span class="text-gray-600 dark:text-gray-400 whitespace-nowrap overflow-hidden transition-all duration-200 w-10 group-hover:w-20 [mask-image:linear-gradient(to_right,black_60%,transparent_100%)] group-hover:[mask-image:none]">
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
  attr :graph_data, :map, required: true

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
          <div
            id="workflow-graph"
            class="h-96 rounded-md overflow-hidden shadow-inner bg-gray-50 dark:bg-gray-900 workflow-graph-canvas"
            phx-hook="WorkflowGraph"
            phx-target={@myself}
            phx-update="ignore"
          >
            <svg class="w-full h-full"></svg>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Stats Grid

  attr :workflow, :any, required: true
  attr :sub_workflows, :list, required: true

  defp stats_grid(assigns) do
    queues = Map.get(assigns.workflow.meta || %{}, "queues", [])
    assigns = assign(assigns, queues: queues)

    ~H"""
    <div class="flex flex-col gap-4 h-full" id="workflow-stats">
      <div class="grid grid-cols-4 gap-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-md">
        <div class="flex flex-col col-span-4">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Workflow ID
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 font-mono">
            {@workflow.id}
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

        <div class="flex flex-col col-span-2">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Status
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 capitalize">
            {@workflow.state}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-4 gap-4 px-3">
        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Subs
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {length(@sub_workflows)}
          </span>
        </div>

        <div class="flex flex-col col-span-3">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Queues
          </span>
          <div class="flex flex-wrap items-center gap-1.5">
            <span
              :for={queue <- @queues}
              class="inline-flex items-center px-1.5 py-0.5 rounded text-sm bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400"
            >
              {queue}
            </span>
          </div>
        </div>
      </div>
    </div>
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
    <span :if={is_nil(@started)}>—</span>
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

  # Sub-workflows Section

  attr :myself, :any, required: true
  attr :subs_open?, :boolean, required: true
  attr :sub_workflows, :list, required: true

  defp sub_workflows_section(assigns) do
    subs_count = length(assigns.sub_workflows)
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
                    ID
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider">
                    Progress
                  </th>
                  <th class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider">
                    Started
                  </th>
                  <th class="px-3 py-2 text-right text-xs font-medium uppercase tracking-wider">
                    Duration
                  </th>
                  <th class="px-3 py-2 text-center text-xs font-medium uppercase tracking-wider">
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
    <.link navigate={oban_path([:workflows, @workflow.id])} class="contents">
      <tr class="hover:bg-gray-100 dark:hover:bg-gray-700/50 cursor-pointer">
        <td class="px-3 py-3 font-medium text-sm text-gray-700 dark:text-gray-300">
          {@workflow.name || @workflow.id}
        </td>
        <td class="px-3 py-3 text-sm text-gray-500 dark:text-gray-400 font-mono">
          {@workflow.id}
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
        <td class="px-3 py-3 text-sm text-gray-500 dark:text-gray-400">
          <.format_started_at workflow={@workflow} />
        </td>
        <td class="px-3 py-3 text-right text-sm text-gray-500 dark:text-gray-400">
          <.format_duration workflow={@workflow} />
        </td>
        <td class="px-3 py-3 text-center">
          <.status_icon state={@state} />
        </td>
      </tr>
    </.link>
    """
  end

  attr :state, :string, default: nil

  defp status_icon(assigns) do
    ~H"""
    <span class="inline-flex">
      <%= case @state do %>
        <% "executing" -> %>
          <Icons.play_circle class="w-5 h-5 text-emerald-400" />
        <% "completed" -> %>
          <Icons.check_circle class="w-5 h-5 text-cyan-400" />
        <% "retryable" -> %>
          <Icons.arrow_path class="w-5 h-5 text-yellow-400" />
        <% "cancelled" -> %>
          <Icons.x_circle class="w-5 h-5 text-violet-400" />
        <% "discarded" -> %>
          <Icons.exclamation_circle class="w-5 h-5 text-rose-400" />
        <% _ -> %>
          <Icons.minus_circle class="w-5 h-5 text-gray-400" />
      <% end %>
    </span>
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
    graph_open? = not socket.assigns[:graph_open?]

    socket = assign(socket, :graph_open?, graph_open?)
    socket = if graph_open?, do: push_graph_data(socket), else: socket

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

  defp cancel_tooltip(true), do: "Cancel all jobs in this workflow"
  defp cancel_tooltip(false), do: "Cancel requires Oban Pro"

  defp retry_tooltip(true), do: "Retry failed jobs in this workflow"
  defp retry_tooltip(false), do: "Retry requires Oban Pro"

  defp has_retryable?(workflow) do
    workflow.retryable + workflow.discarded + workflow.cancelled > 0
  end

  defp count_sub_states(subs) do
    init = Map.new(@states, &{&1, 0})

    Enum.reduce(subs, init, fn sub, acc ->
      Map.update!(acc, String.to_existing_atom(sub.state), &(&1 + 1))
    end)
  end
end
