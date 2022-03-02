defmodule Oban.Web.Jobs.TimelineComponent do
  @moduledoc false

  use Phoenix.Component

  alias Oban.Web.Timing

  @empty_time "—"

  @state_to_timestamp %{
    "cancelled" => :cancelled_at,
    "completed" => :completed_at,
    "discarded" => :discarded_at,
    "executing" => :attempted_at,
    "inserted" => :inserted_at,
    "scheduled" => :scheduled_at
  }

  @state_to_relative %{
    "cancelled" => :relative_cancelled_at,
    "completed" => :relative_completed_at,
    "discarded" => :relative_discarded_at,
    "executing" => :relative_attempted_at,
    "inserted" => :relative_inserted_at,
    "scheduled" => :relative_scheduled_at
  }

  def render(assigns) do
    ~H"""
    <div id={"timeline-for-#{@state}"} class="w-1/4 flex flex-col" data-title={timestamp_title(@state, @job)} phx-hook="Tippy">
      <span class={"flex self-center justify-center items-center h-16 w-16 transition-colors duration-200 rounded-full #{timeline_class(@state, @job)}"}>
        <%= if timeline_icon(@state, @job) == :checkmark do %>
          <svg class="h-12 w-12" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path></svg>
        <% end %>
        <%= if timeline_icon(@state, @job) == :spinner do %>
          <svg class="h-12 w-12 animate-spin" fill="currentColor" viewBox="0 0 20 20"><path d="M10 1a.9.9 0 110 1.8 7.2 7.2 0 107.2 7.2.9.9 0 111.8 0 9 9 0 11-9-9z" fill-rule="nonzero"/></svg>
        <% end %>
      </span>
      <span class="block text-sm text-center font-semibold mt-2"><%= timestamp_name(@state, @job) %></span>
      <span class="block text-sm text-center tabular"><%= timeline_time(@state, @job) %></span>
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

  defp timeline_time(state, job) do
    for_state = Map.get(@state_to_relative, state)
    timestamp = Map.get(job, for_state)

    case {state, job.state, timestamp} do
      {_, _, nil} ->
        @empty_time

      {state, "retryable", _} when state in ~w(completed executing) ->
        @empty_time

      {"completed", "executing", _} ->
        @empty_time

      {"executing", "executing", at} ->
        Timing.to_duration(at)

      {"completed", _, at} ->
        duration =
          job.attempted_at
          |> NaiveDateTime.diff(job.completed_at)
          |> Timing.to_duration()

        "#{Timing.to_words(at)} (#{duration})"

      {_, _, at} ->
        Timing.to_words(at)
    end
  end

  defp absolute_state(state, job) do
    for_state = Map.get(@state_to_timestamp, state)
    timestamp = Map.get(job, for_state)

    absolute_state(state, job.state, timestamp)
  end

  defp absolute_state("completed", "completed", at) when not is_nil(at), do: :finished
  defp absolute_state("completed", "executing", _), do: :unstarted
  defp absolute_state("completed", "retryable", _), do: :unstarted
  defp absolute_state("cancelled", "cancelled", _), do: :finished
  defp absolute_state("cancelled", "retryable", _), do: :unstarted
  defp absolute_state("discarded", "discarded", _), do: :finished
  defp absolute_state("discarded", "retryable", _), do: :unstarted
  defp absolute_state("executing", "retryable", _), do: :unstarted
  defp absolute_state("scheduled", "retryable", _), do: :retrying
  defp absolute_state(state, state, _), do: :started
  defp absolute_state(_, _, at) when not is_nil(at), do: :finished
  defp absolute_state(_, _, _), do: :unstarted

  defp truncate_sec(nil), do: @empty_time
  defp truncate_sec(datetime), do: NaiveDateTime.truncate(datetime, :second)
end
