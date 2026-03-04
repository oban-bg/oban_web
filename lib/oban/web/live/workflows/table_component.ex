defmodule Oban.Web.Workflows.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers, only: [integer_to_estimate: 1, oban_path: 1]

  alias Oban.Web.Timing

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="workflows-table" class="min-w-full">
      <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-500">
        <.header label="name" class="pl-3 w-1/3 text-left" />
        <div class="ml-auto flex items-center space-x-6">
          <.header label="subs" class="w-14 text-center" />
          <.header label="progress" class="w-64 text-center" />
          <.header label="activity" class="w-44 text-center" />
          <.header label="duration" class="w-24 text-right" />
          <.header label="started" class="w-24 text-right" />
          <.header label="status" class="w-16 pr-4 text-right" />
        </div>
      </ul>

      <div :if={Enum.empty?(@workflows)} class="py-16 px-6 text-center">
        <Icons.rectangle_group class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" />
        <h3 class="mt-4 text-xl font-semibold text-gray-900 dark:text-gray-100">No workflows</h3>
        <p class="mt-2 text-base text-gray-500 dark:text-gray-400 max-w-md mx-auto">
          Workflows coordinate jobs with dependencies. They'll appear here once jobs with workflow metadata are enqueued.
        </p>
        <div class="mt-4">
          <a
            href="https://oban.pro/docs/pro/Oban.Pro.Workflow.html"
            target="_blank"
            rel="noopener"
            class="text-base font-medium text-violet-600 hover:text-violet-500 dark:text-violet-400 dark:hover:text-violet-300"
          >
            Learn about workflows <span aria-hidden="true">&rarr;</span>
          </a>
        </div>
      </div>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.workflow_row :for={workflow <- @workflows} workflow={workflow} />
      </ul>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :class, :string, default: ""

  defp header(assigns) do
    ~H"""
    <span class={[@class, "text-xs font-medium uppercase tracking-wider py-1.5"]}>
      {@label}
    </span>
    """
  end

  attr :workflow, :map, required: true

  defp workflow_row(assigns) do
    ~H"""
    <li id={"workflow-#{@workflow.id}"}>
      <.link
        navigate={oban_path([:workflows, @workflow.id])}
        class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30"
      >
        <div class="pl-3 py-3.5 flex flex-grow items-center">
          <div class="w-1/3">
            <span class="font-semibold text-sm text-gray-700 dark:text-gray-300">
              {@workflow.display_name}
            </span>

            <div :if={Enum.any?(@workflow.queues)} class="flex flex-wrap items-center gap-1.5 mt-1">
              <span
                :for={queue <- @workflow.queues}
                class="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400"
              >
                {queue}
              </span>
            </div>
          </div>

          <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
            <.subs_count workflow={@workflow} />

            <.progress_bar workflow={@workflow} />

            <.activity_counts workflow={@workflow} />

            <.format_duration workflow={@workflow} />

            <.started_at workflow={@workflow} />

            <div class="w-16 pr-4 flex justify-end">
              <.status_indicator state={@workflow.state} />
            </div>
          </div>
        </div>
      </.link>
    </li>
    """
  end

  attr :workflow, :map, required: true

  defp subs_count(assigns) do
    count = map_size(assigns.workflow.subs)
    assigns = assign(assigns, count: count)

    ~H"""
    <div class="w-14 flex justify-center">
      <span class="text-sm text-gray-500 dark:text-gray-400">
        {@count}
      </span>
    </div>
    """
  end

  attr :workflow, :map, required: true

  defp progress_bar(assigns) do
    completed = Map.get(assigns.workflow.counts, :completed, 0)
    total = assigns.workflow.total
    percent = if total > 0, do: min(round(completed / total * 100), 100), else: 0

    assigns = assign(assigns, completed: completed, total: total, percent: percent)

    ~H"""
    <div class="w-64 flex items-center">
      <div class="w-48 h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
        <div class="h-full rounded-full bg-cyan-400" style={"width: #{@percent}%"} />
      </div>
      <span class="w-14 text-left tabular pl-2 text-sm">{@completed}/{@total}</span>
    </div>
    """
  end

  attr :workflow, :map, required: true

  defp activity_counts(assigns) do
    counts = assigns.workflow.counts
    id = assigns.workflow.id

    assigns =
      assign(assigns,
        id: id,
        executing: Map.get(counts, :executing, 0),
        available: Map.get(counts, :available, 0),
        retryable: Map.get(counts, :retryable, 0),
        discarded: Map.get(counts, :discarded, 0)
      )

    ~H"""
    <div class="w-44 flex items-center justify-end text-sm">
      <.state_count id={"#{@id}-exec"} count={@executing} color="emerald" title="Executing" />
      <.state_count id={"#{@id}-avail"} count={@available} color="cyan" title="Available" />
      <.state_count id={"#{@id}-retry"} count={@retryable} color="yellow" title="Retryable" />
      <.state_count id={"#{@id}-disc"} count={@discarded} color="pink" title="Discarded" />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :count, :integer, required: true
  attr :color, :string, required: true
  attr :title, :string, required: true

  defp state_count(assigns) do
    bg_class =
      case {assigns.count, assigns.color} do
        {0, _} -> "bg-gray-300 dark:bg-gray-600"
        {_, "emerald"} -> "bg-emerald-400"
        {_, "cyan"} -> "bg-cyan-400"
        {_, "yellow"} -> "bg-yellow-400"
        {_, "pink"} -> "bg-pink-400"
      end

    assigns = assign(assigns, bg_class: bg_class)

    ~H"""
    <span class="w-11 flex items-center space-x-1.5" data-title={@title} id={@id} phx-hook="Tippy">
      <span class="flex-1 text-right">{integer_to_estimate(@count)}</span>
      <span class={["w-2 h-2 rounded-full", @bg_class]} />
    </span>
    """
  end

  attr :workflow, :map, required: true

  defp started_at(assigns) do
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
      class="w-24 text-right text-sm"
      id={"wf-started-#{@workflow.id}"}
      data-timestamp={DateTime.to_unix(@started, :millisecond)}
      phx-hook="Relativize"
      phx-update="ignore"
    >
      -
    </span>
    <span :if={is_nil(@started)} class="w-24 text-right text-sm">
      -
    </span>
    """
  end

  attr :workflow, :map, required: true

  defp format_duration(assigns) do
    workflow = assigns.workflow
    executing? = workflow.state == :executing
    started? = not is_nil(workflow.started_at)

    formatted =
      if is_nil(workflow.duration) or workflow.duration <= 0 do
        "-"
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
      class="w-24 text-right text-sm"
      id={"wf-duration-#{@workflow.id}"}
      data-timestamp={DateTime.to_unix(@started_at, :millisecond)}
      data-relative-mode="duration"
      phx-hook="Relativize"
      phx-update="ignore"
    >
      -
    </span>
    <span :if={not (@executing? and @started?)} class="w-24 text-right text-sm">
      {@formatted}
    </span>
    """
  end

  attr :state, :atom, required: true

  defp status_indicator(assigns) do
    ~H"""
    <span
      data-title={status_title(@state)}
      id={"workflow-state-#{System.unique_integer([:positive])}"}
      phx-hook="Tippy"
    >
      <%= case @state do %>
        <% :executing -> %>
          <Icons.play_circle class="w-5 h-5 text-emerald-400" />
        <% :completed -> %>
          <Icons.check_circle class="w-5 h-5 text-cyan-400" />
        <% :cancelled -> %>
          <Icons.x_circle class="w-5 h-5 text-violet-400" />
        <% :discarded -> %>
          <Icons.exclamation_circle class="w-5 h-5 text-rose-400" />
        <% _ -> %>
          <Icons.minus_circle class="w-5 h-5 text-gray-400" />
      <% end %>
    </span>
    """
  end

  defp status_title(:executing), do: "Executing"
  defp status_title(:completed), do: "Completed"
  defp status_title(:cancelled), do: "Cancelled"
  defp status_title(:discarded), do: "Discarded"
  defp status_title(_), do: "Unknown"
end
