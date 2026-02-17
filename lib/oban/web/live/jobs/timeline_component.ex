defmodule Oban.Web.Jobs.TimelineComponent do
  @moduledoc false

  use Phoenix.Component

  alias Oban.Web.Components.Icons
  alias Oban.Web.Timing

  @status_colors %{
    inactive:
      {"border-gray-300 dark:border-gray-600", "bg-gray-100 dark:bg-gray-800",
       "text-gray-400 dark:text-gray-500"},
    active: {"border-blue-400", "bg-blue-400/10", "text-blue-600 dark:text-blue-400"},
    completed:
      {"border-emerald-400", "bg-emerald-400/10", "text-emerald-600 dark:text-emerald-400"},
    negative: {"border-rose-400", "bg-rose-400/10", "text-rose-600 dark:text-rose-400"}
  }

  def render(assigns) do
    assigns =
      assigns
      |> assign(:path, compute_path(assigns.job))
      |> assign(:now, DateTime.from_unix!(assigns.os_time))

    ~H"""
    <div
      id="job-timeline"
      class="w-full py-4 px-6"
      phx-hook="TimelineConnectors"
      data-entry-scheduled={@path.entry == "scheduled"}
      data-entry-retryable={@path.entry == "retryable"}
      data-engaged={@path.engaged}
      data-terminal-completed={@path.terminal == "completed"}
      data-terminal-cancelled={@path.terminal == "cancelled"}
      data-terminal-discarded={@path.terminal == "discarded"}
    >
      <div id="timeline-boxes" class="relative">
        <svg
          id="timeline-connectors"
          class="absolute inset-0 overflow-visible pointer-events-none"
        />

        <div class="relative grid grid-cols-4 gap-x-12 gap-y-3">
          <.state_box state="scheduled" job={@job} path={@path} now={@now} />
          <div></div>
          <div></div>
          <.state_box state="completed" job={@job} path={@path} now={@now} />

          <div></div>
          <.state_box state="available" job={@job} path={@path} now={@now} />
          <.state_box state="executing" job={@job} path={@path} now={@now} />
          <.state_box state="cancelled" job={@job} path={@path} now={@now} />

          <.state_box state="retryable" job={@job} path={@path} now={@now} />
          <div></div>
          <div></div>
          <.state_box state="discarded" job={@job} path={@path} now={@now} />
        </div>
      </div>
    </div>
    """
  end

  attr :state, :string, required: true
  attr :job, :map, required: true
  attr :path, :map, required: true
  attr :now, :any, required: true

  defp state_box(assigns) do
    status = box_status(assigns.state, assigns.job, assigns.path)
    visual_status = visual_status(assigns.state, status)
    {border_class, bg_class, text_color} = Map.fetch!(@status_colors, visual_status)

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:border_class, border_class)
      |> assign(:bg_class, bg_class)
      |> assign(:text_color, text_color)
      |> assign(:timestamp, format_timestamp(assigns.state, assigns.job, assigns.now))
      |> assign(:tooltip, timestamp_title(assigns.state, assigns.job))

    ~H"""
    <div
      class={"flex items-center justify-between h-12 rounded-lg border-2 px-3 #{@border_class} #{@bg_class}"}
      data-title={@tooltip}
      phx-hook="Tippy"
      id={"timeline-#{@state}"}
    >
      <div class="flex items-center gap-2">
        <span class={"flex items-center justify-center w-5 h-5 #{@text_color}"}>
          <.state_icon status={@status} state={@state} />
        </span>
        <span class={"text-sm font-semibold capitalize #{@text_color}"}>
          {@state}
        </span>
      </div>
      <span class={"text-xs tabular-nums #{@text_color}"}>
        {@timestamp || "—"}
      </span>
    </div>
    """
  end

  attr :status, :atom, required: true
  attr :state, :string, required: true

  defp state_icon(%{status: :inactive} = assigns) do
    ~H"""
    <Icons.ellipsis_horizontal_circle class="w-5 h-5" />
    """
  end

  defp state_icon(%{state: state} = assigns) when state in ~w(completed cancelled discarded) do
    ~H"""
    <Icons.check class="w-5 h-5" />
    """
  end

  defp state_icon(%{status: :active} = assigns) do
    ~H"""
    <svg class="w-4 h-4 animate-spin" fill="currentColor" viewBox="0 0 20 20">
      <path
        d="M10 1a.9.9 0 110 1.8 7.2 7.2 0 107.2 7.2.9.9 0 111.8 0 9 9 0 11-9-9z"
        fill-rule="nonzero"
      />
    </svg>
    """
  end

  defp state_icon(%{status: :completed} = assigns) do
    ~H"""
    <Icons.check class="w-5 h-5" />
    """
  end

  # Path computation

  defp compute_path(job) do
    %{
      entry: compute_entry_state(job),
      terminal: compute_terminal_state(job),
      engaged: not is_nil(job.attempted_at)
    }
  end

  defp compute_entry_state(job) do
    cond do
      job.state == "retryable" -> "retryable"
      job.attempt > 1 -> "retryable"
      true -> "scheduled"
    end
  end

  defp compute_terminal_state(job) do
    case job.state do
      "completed" -> "completed"
      "cancelled" -> "cancelled"
      "discarded" -> "discarded"
      _ -> nil
    end
  end

  # Box status

  defp box_status(state, job, path) do
    cond do
      state == job.state -> :active
      state_completed?(state, job, path) -> :completed
      true -> :inactive
    end
  end

  defp state_completed?("scheduled", job, path) do
    path.entry == "scheduled" and job.state != "scheduled"
  end

  defp state_completed?("retryable", _job, path) do
    path.entry == "retryable"
  end

  defp state_completed?("available", job, _path) do
    not is_nil(job.attempted_at) and job.state not in ["available", "scheduled", "retryable"]
  end

  defp state_completed?("executing", job, _path) do
    job.state in ["completed", "cancelled", "discarded"] and not is_nil(job.attempted_at)
  end

  defp state_completed?("completed", job, _path), do: job.state == "completed"
  defp state_completed?("cancelled", job, _path), do: job.state == "cancelled"
  defp state_completed?("discarded", job, _path), do: job.state == "discarded"

  defp visual_status("completed", status) when status in [:active, :completed], do: :completed

  defp visual_status(state, status)
       when state in ["cancelled", "discarded"] and status in [:active, :completed], do: :negative

  defp visual_status(_state, :inactive), do: :inactive
  defp visual_status(_state, :active), do: :active
  defp visual_status(_state, :completed), do: :completed

  # Timestamp formatting

  defp format_timestamp("scheduled", job, now) do
    if job.attempt > 1 or job.state == "retryable" do
      nil
    else
      format_time(job.scheduled_at, now)
    end
  end

  defp format_timestamp("retryable", job, now) do
    if job.state == "retryable" or job.attempt > 1 do
      format_time(job.scheduled_at, now)
    else
      nil
    end
  end

  defp format_timestamp("available", job, now) do
    if job.state != "retryable" and job.attempted_at do
      format_time(job.attempted_at, now)
    else
      nil
    end
  end

  defp format_timestamp("executing", job, now) do
    cond do
      job.state == "executing" ->
        relative = job.attempted_at |> DateTime.diff(now) |> Timing.to_words()
        duration = job.attempted_at |> DateTime.diff(now) |> Timing.to_duration()

        "#{relative} (#{duration})"

      job.state in ["completed", "cancelled", "discarded"] ->
        terminal_at = job.completed_at || job.cancelled_at || job.discarded_at

        relative = job.attempted_at |> DateTime.diff(now) |> Timing.to_words()
        duration = job.attempted_at |> DateTime.diff(terminal_at) |> Timing.to_duration()

        "#{relative} (#{duration})"

      true ->
        nil
    end
  end

  defp format_timestamp("completed", job, now) do
    format_time(job.completed_at, now)
  end

  defp format_timestamp("cancelled", job, now) do
    format_time(job.cancelled_at, now)
  end

  defp format_timestamp("discarded", job, now) do
    format_time(job.discarded_at, now)
  end

  defp format_time(nil, _now), do: nil

  defp format_time(timestamp, now) do
    timestamp
    |> DateTime.diff(now)
    |> Timing.to_words()
  end

  defp timestamp_title(state, job) do
    timestamp =
      case state do
        "scheduled" ->
          if(job.attempt > 1 or job.state == "retryable", do: nil, else: job.scheduled_at)

        "retryable" ->
          if(job.state == "retryable" or job.attempt > 1, do: job.scheduled_at)

        "available" ->
          if(job.state == "retryable", do: nil, else: job.attempted_at)

        "executing" ->
          job.attempted_at

        "completed" ->
          job.completed_at

        "cancelled" ->
          job.cancelled_at

        "discarded" ->
          job.discarded_at
      end

    label =
      case state do
        "scheduled" -> "Scheduled At"
        "retryable" -> "Retrying At"
        "available" -> "Started At"
        "executing" -> "Attempted At"
        "completed" -> "Completed At"
        "cancelled" -> "Cancelled At"
        "discarded" -> "Discarded At"
      end

    "#{label}: #{truncate_sec(timestamp)}"
  end

  defp truncate_sec(nil), do: "—"
  defp truncate_sec(datetime), do: NaiveDateTime.truncate(datetime, :second)
end
