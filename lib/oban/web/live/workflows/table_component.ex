defmodule Oban.Web.Workflows.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers, only: [integer_to_estimate: 1, oban_path: 1]

  alias Oban.Web.Timing

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="workflows-table" class="min-w-full">
      <Core.table_header class="border-l-4 border-l-transparent">
        <Core.column_header label="name" class="pl-3 flex-1 min-w-0 text-left" />
        <div class="flex items-center space-x-6">
          <Core.column_header label="progress" class="w-88 text-left" />
          <Core.column_header label="activity" class="w-48 text-left" />
          <Core.column_header label="duration" class="w-24 text-right" />
          <Core.column_header label="started" class="w-24 text-right" />
          <Core.column_header label="status" class="w-16 pr-4 text-right" />
        </div>
      </Core.table_header>

      <Core.no_matches
        :if={Enum.empty?(@workflows) and @filtered?}
        id="workflows-no-matches"
        label="No workflows match the current filters."
        clear={oban_path(:workflows)}
      />

      <Core.empty_state
        :if={Enum.empty?(@workflows) and not @filtered?}
        icon="icon-rectangle-group"
        title="No workflows"
      >
        Workflows coordinate jobs with dependencies. They'll appear here once jobs with workflow
        metadata are enqueued.
        <:actions>
          <Core.learn_link href="https://oban.pro/docs/pro/Oban.Pro.Workflow.html">
            Learn about workflows
          </Core.learn_link>
        </:actions>
      </Core.empty_state>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.workflow_row :for={workflow <- @workflows} workflow={workflow} />
      </ul>
    </div>
    """
  end

  attr :workflow, :map, required: true

  defp workflow_row(assigns) do
    ~H"""
    <li id={"workflow-#{@workflow.id}"}>
      <.link
        patch={oban_path([:workflows, @workflow.id])}
        class={[
          "flex items-center border-l-4 hover:bg-gray-50 dark:hover:bg-gray-950/30",
          "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-blue-500",
          attention_class(@workflow.attention)
        ]}
        data-attention={@workflow.attention}
      >
        <div class="pl-3 py-3.5 flex flex-grow items-center min-w-0">
          <div class="flex-1 min-w-0">
            <span
              class="block font-semibold text-sm text-gray-700 dark:text-gray-300 truncate"
              title={@workflow.display_name}
            >
              {@workflow.display_name}
            </span>

            <div
              :if={@workflow.compensation? or Enum.any?(@workflow.queues)}
              class="flex flex-wrap items-center gap-1.5 mt-1"
            >
              <span
                :if={@workflow.compensation?}
                id={"workflow-comp-#{@workflow.id}"}
                class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400"
                data-title={"Rolls back the completed steps of #{@workflow.display_name}"}
                phx-hook="Tippy"
              >
                <Icons.icon name="icon-arrow-path-rounded" class="w-3.5 h-3.5" /> compensation
              </span>

              <span
                :for={queue <- @workflow.queues}
                class="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400"
              >
                {queue}
              </span>
            </div>
          </div>

          <div class="flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
            <.progress_bar workflow={@workflow} />

            <.activity_counts workflow={@workflow} />

            <.format_duration workflow={@workflow} />

            <.started_at workflow={@workflow} />

            <div class="w-16 pr-4 flex justify-end">
              <.status_indicator id={@workflow.id} state={@workflow.status} />
            </div>
          </div>
        </div>
      </.link>
    </li>
    """
  end

  # The bar segment, the count dot, and the status icon already carry the state color at full
  # strength, so the edge is a pale cue for scanning rather than a fourth alarm.
  defp attention_class(:discarded), do: "border-rose-200 dark:border-rose-900"
  defp attention_class(:retryable), do: "border-yellow-200 dark:border-yellow-900"
  defp attention_class(_attention), do: "border-transparent"

  # Terminal states fill the bar first, then in-flight states, so the rose and violet
  # segments read as "done, but not successfully" rather than as progress.
  @segments [
    {:completed, "bg-cyan-400"},
    {:cancelled, "bg-violet-400"},
    {:discarded, "bg-rose-400"},
    {:executing, "bg-emerald-400"},
    {:retryable, "bg-yellow-400"}
  ]

  @buckets [
    {:suspended, "bg-gray-400", "Suspended", "waiting on dependencies"},
    {:pending, "bg-blue-400", "Pending", "available or scheduled to run"},
    {:retryable, "bg-yellow-400", "Retryable", "failed and waiting to retry"},
    {:executing, "bg-emerald-400", "Executing", "running now"},
    {:completed, "bg-cyan-400", "Completed", "finished successfully"},
    {:cancelled, "bg-violet-400", "Cancelled", "stopped deliberately"},
    {:discarded, "bg-rose-400", "Discarded", "failed permanently"}
  ]

  attr :workflow, :map, required: true

  defp progress_bar(assigns) do
    %{id: id, activity: activity, total: total, display_name: name} = assigns.workflow

    segments =
      for {state, class} <- @segments, count = Map.fetch!(activity, state), count > 0 do
        {state, class, Float.round(count / total * 100, 2)}
      end

    assigns =
      assign(assigns,
        id: id,
        name: name,
        completed: activity.completed,
        total: total,
        segments: segments,
        summary: activity_summary(activity, total)
      )

    ~H"""
    <div class="w-88 flex items-center">
      <div
        id={"wf-progress-#{@id}"}
        class="w-64 h-2 flex bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden"
        role="progressbar"
        aria-label={"Progress of #{@name}"}
        aria-valuemin="0"
        aria-valuemax={@total}
        aria-valuenow={@completed}
        aria-valuetext={@summary}
      >
        <div
          :for={{state, class, width} <- @segments}
          class={["h-full shrink-0", class]}
          style={"width: #{width}%"}
          data-state={state}
        />
      </div>
      <span class="w-24 text-left tabular pl-2 text-sm truncate">{@completed}/{@total}</span>
    </div>
    """
  end

  defp activity_summary(activity, total) do
    parts =
      for {state, _class, label, _hint} <- @buckets,
          count = Map.fetch!(activity, state),
          count > 0 do
        "#{count} #{String.downcase(label)}"
      end

    case parts do
      [] -> "No jobs"
      parts -> "#{Enum.join(parts, ", ")} of #{total}"
    end
  end

  attr :workflow, :map, required: true

  # Only buckets with jobs in them are shown; the bar already carries the shape of the
  # workflow, so a row of zeros adds nothing but noise.
  defp activity_counts(assigns) do
    buckets =
      for {state, class, label, hint} <- @buckets,
          count = Map.fetch!(assigns.workflow.activity, state),
          count > 0,
          do: {state, class, label, hint, count}

    assigns = assign(assigns, buckets: buckets)

    ~H"""
    <div class="w-48 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm">
      <.state_count
        :for={{state, class, label, hint, count} <- @buckets}
        id={"#{@workflow.id}-#{state}"}
        count={count}
        dot_class={class}
        title={label}
        hint={hint}
      />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :count, :integer, required: true
  attr :dot_class, :string, required: true
  attr :title, :string, required: true
  attr :hint, :string, required: true

  defp state_count(assigns) do
    ~H"""
    <span
      class="flex items-center space-x-1"
      data-title={"#{@title}: #{@hint}"}
      id={@id}
      phx-hook="Tippy"
    >
      <span>{integer_to_estimate(@count)}</span>
      <span class="sr-only">{@title}</span>
      <span class={["w-2 h-2 rounded-full shrink-0", @dot_class]} />
    </span>
    """
  end

  attr :workflow, :map, required: true

  defp started_at(assigns) do
    %{status: status, started_at: started_at} = assigns.workflow

    started = if status != :pending, do: started_at

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
    wf = assigns.workflow
    executing? = wf.status == :executing
    started? = not is_nil(wf.started_at)

    duration =
      if wf.started_at && wf.completed_at do
        DateTime.diff(wf.completed_at, wf.started_at, :millisecond)
      end

    formatted =
      if is_nil(duration) or duration <= 0 do
        "-"
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

  attr :id, :string, required: true
  attr :state, :atom, required: true

  defp status_indicator(assigns) do
    {icon, class, hint} = status_glyph(assigns.state)

    assigns =
      assign(assigns, icon: icon, class: class, hint: hint, title: status_title(assigns.state))

    ~H"""
    <span
      data-title={"#{@title}: #{@hint}"}
      id={"workflow-state-#{@id}"}
      phx-hook="Tippy"
    >
      <Icons.icon name={@icon} class={["w-5 h-5", @class]} />
      <span class="sr-only">{@title}</span>
    </span>
    """
  end

  defp status_glyph(:executing) do
    {"icon-play-circle", "text-emerald-600 dark:text-emerald-400", "jobs are still running"}
  end

  defp status_glyph(:retryable) do
    {"icon-arrow-path", "text-yellow-700 dark:text-yellow-400",
     "jobs failed and are waiting to retry"}
  end

  defp status_glyph(:completed) do
    {"icon-check-circle", "text-cyan-600 dark:text-cyan-400", "every job finished successfully"}
  end

  defp status_glyph(:cancelled) do
    {"icon-x-circle", "text-violet-600 dark:text-violet-400", "jobs were cancelled"}
  end

  defp status_glyph(:discarded) do
    {"icon-exclamation-circle", "text-rose-600 dark:text-rose-400",
     "at least one job was discarded"}
  end

  defp status_glyph(:pending) do
    {"icon-clock", "text-gray-500 dark:text-gray-400", "no job has started yet"}
  end

  defp status_glyph(_state) do
    {"icon-minus-circle", "text-gray-500 dark:text-gray-400", "state not recognized"}
  end

  defp status_title(state), do: state |> to_string() |> String.capitalize()
end
