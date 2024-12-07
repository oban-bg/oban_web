defmodule Oban.Web.Jobs.TimelineComponent do
  @moduledoc false

  use Phoenix.Component

  alias Oban.Web.Components.Icons
  alias Oban.Web.Timing

  @empty_time "—"

  @state_to_timestamp %{
    "cancelled" => :cancelled_at,
    "discarded" => :discarded_at,
    "executing" => :attempted_at,
    "inserted" => :inserted_at,
    "scheduled" => :scheduled_at
  }

  def render(assigns) do
    ~H"""
    <div
      id={"timeline-for-#{@state}"}
      class="w-1/4 flex flex-col"
      data-title={timestamp_title(@state, @job)}
      phx-hook="Tippy"
    >
      <span class={"flex self-center justify-center items-center h-16 w-16 transition-colors duration-200 rounded-full #{timeline_class(@state, @job)}"}>
        <%= if timeline_icon(@state, @job) == :checkmark do %>
          <Icons.check class="w-12 h-12" />
        <% end %>
        <%= if timeline_icon(@state, @job) == :spinner do %>
          <svg class="h-12 w-12 animate-spin" fill="currentColor" viewBox="0 0 20 20">
            <path
              d="M10 1a.9.9 0 110 1.8 7.2 7.2 0 107.2 7.2.9.9 0 111.8 0 9 9 0 11-9-9z"
              fill-rule="nonzero"
            />
          </svg>
        <% end %>
      </span>
      <span class="block text-sm text-center font-semibold mt-2">
        {timestamp_name(@state, @job)}
      </span>
      <span class="block text-sm text-center tabular">
        {timeline_time(@state, @job, @os_time)}
      </span>
    </div>
    """
  end

  # Helpers

  defp timestamp_title(state, job) do
    case state do
      "inserted" -> "Inserted At: #{truncate_sec(job.inserted_at)}"
      "scheduled" -> "Scheduled At: #{truncate_sec(job.scheduled_at)}"
      "executing" -> "Attempted At: #{truncate_sec(job.attempted_at)}"
      "completed" -> "Completed At: #{truncate_sec(job.completed_at)}"
      "cancelled" -> "Cancelled At: #{truncate_sec(job.cancelled_at)}"
      "discarded" -> "Discarded At: #{truncate_sec(job.discarded_at)}"
    end
  end

  defp timeline_class(state, job) do
    case absolute_state(state, job) do
      :finished -> "bg-green-500 text-white"
      :retrying -> "bg-orange-400 text-white"
      :started -> "bg-yellow-400 text-white"
      :unstarted -> "bg-gray-100 text-white dark:bg-black dark:bg-opacity-25"
    end
  end

  defp timeline_icon(state, job) do
    case absolute_state(state, job) do
      :finished -> :checkmark
      :retrying -> :spinner
      :started -> :spinner
      :unstarted -> nil
    end
  end

  defp timestamp_name(state, job) do
    case {state, job.state} do
      {"retryable", "retryable"} -> "Retryable"
      {"retryable", _} -> "Scheduled"
      {"executing", "executing"} -> "Executing"
      {"executing", _} -> "Completed"
      _ -> String.capitalize(state)
    end
  end

  defp timeline_time(state, job, os_time) do
    for_state = Map.get(@state_to_timestamp, state)
    timestamp = Map.get(job, for_state)
    now = DateTime.from_unix!(os_time)

    case {state, job.state, timestamp} do
      {_, _, nil} ->
        @empty_time

      {"executing", "executing", at} ->
        at
        |> DateTime.diff(now)
        |> Timing.to_duration()

      {"executing", "completed", at} ->
        words =
          at
          |> DateTime.diff(now)
          |> Timing.to_words()

        duration =
          job.attempted_at
          |> DateTime.diff(job.completed_at)
          |> Timing.to_duration()

        "#{words} (#{duration})"

      {"executing", _, _} ->
        @empty_time

      {_, _, at} ->
        at
        |> DateTime.diff(now)
        |> Timing.to_words()
    end
  end

  defp absolute_state(state, job) do
    for_state = Map.get(@state_to_timestamp, state)
    timestamp = Map.get(job, for_state)

    absolute_state(state, job.state, timestamp)
  end

  defp absolute_state("executing", "completed", _), do: :finished
  defp absolute_state("executing", "executing", _), do: :started
  defp absolute_state("executing", _, _), do: :unstarted
  defp absolute_state("cancelled", "cancelled", _), do: :finished
  defp absolute_state("cancelled", "retryable", _), do: :unstarted
  defp absolute_state("discarded", "discarded", _), do: :finished
  defp absolute_state("discarded", "retryable", _), do: :unstarted
  defp absolute_state("scheduled", "retryable", _), do: :retrying
  defp absolute_state(state, state, _), do: :started
  defp absolute_state(_, _, at) when not is_nil(at), do: :finished
  defp absolute_state(_, _, _), do: :unstarted

  defp truncate_sec(nil), do: @empty_time
  defp truncate_sec(datetime), do: NaiveDateTime.truncate(datetime, :second)
end
