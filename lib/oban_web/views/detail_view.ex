defmodule ObanWeb.DetailView do
  use ObanWeb.Web, :view

  alias Oban.Job
  alias ObanWeb.{IconView, Timing}

  @empty_time "—"

  @state_to_timestamp %{
    "completed" => :completed_at,
    "discarded" => :discarded_at,
    "executing" => :attempted_at,
    "inserted" => :inserted_at,
    "scheduled" => :scheduled_at
  }

  @state_to_relative %{
    "completed" => :relative_completed_at,
    "discarded" => :relative_discarded_at,
    "executing" => :relative_attempted_at,
    "inserted" => :relative_inserted_at,
    "scheduled" => :relative_scheduled_at
  }

  @doc """
  Convert a stringified timestamp (i.e. from an error) into a relative time.
  """
  def iso8601_to_words(iso8601, now \\ NaiveDateTime.utc_now()) do
    {:ok, datetime} = NaiveDateTime.from_iso8601(iso8601)

    datetime
    |> NaiveDateTime.diff(now)
    |> Timing.to_words()
  end

  @doc """
  Extract the name of the node that attempted a job.
  """
  def attempted_by(%Job{attempted_by: [node | _]}), do: node
  def attempted_by(%Job{}), do: "Not Attempted"

  @doc """
  Format job tags using a delimiter.
  """
  def formatted_tags(%Job{tags: tags}), do: Enum.join(tags, ", ")

  @doc """
  Determine the correct state modifier class: either `--finished` or `--active`, based on a job's
  state and timestamp.
  """
  def timeline_state(state, %Job{} = job) do
    case absolute_state(state, job) do
      :finished -> "timeline-state--finished"
      :retrying -> "timeline-state--retrying"
      :started -> "timeline-state--started"
      :unstarted -> nil
    end
  end

  @doc """
  Determine the appropriate state icon: either `checkmark` or `spinner`. This must match the class
  returned by `timeline_state/2`.
  """
  def timeline_icon(state, %Job{} = job) do
    case absolute_state(state, job) do
      :finished -> icon("checkmark")
      :retrying -> icon("spinner")
      :started -> icon("spinner")
      :unstarted -> nil
    end
  end

  @doc """
  Format the relative timestamp for a given state.
  """
  def timeline_time(state, %Job{} = job) do
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

  @doc """
  Format a title for the given state based on the timestamp.
  """
  def timestamp_title(state, %Job{} = job) do
    case state do
      "inserted" -> "Inserted At: #{truncate_sec(job.inserted_at)}"
      "scheduled" -> "Scheduled At: #{truncate_sec(job.scheduled_at)}"
      "executing" -> "Attempted At: #{truncate_sec(job.attempted_at)}"
      "completed" -> "Completed At: #{truncate_sec(job.completed_at)}"
      "discarded" -> "Discarded At: #{truncate_sec(job.discarded_at)}"
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
  defp absolute_state("discarded", "discarded", _), do: :finished
  defp absolute_state("discarded", "retryable", _), do: :unstarted
  defp absolute_state("executing", "retryable", _), do: :unstarted
  defp absolute_state("scheduled", "retryable", _), do: :retrying
  defp absolute_state(state, state, _), do: :started
  defp absolute_state(_, _, at) when not is_nil(at), do: :finished
  defp absolute_state(_, _, _), do: :unstarted

  defp icon(name), do: render(IconView, name <> ".html")

  defp truncate_sec(nil), do: @empty_time
  defp truncate_sec(datetime), do: NaiveDateTime.truncate(datetime, :second)
end
