defmodule ObanWeb.Helpers do
  @moduledoc false

  alias Oban.Job
  alias ObanWeb.Timing

  @spec integer_to_delimited(integer()) :: String.t()
  def integer_to_delimited(integer) when is_integer(integer) do
    integer
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3, 3, [])
    |> Enum.join(",")
    |> String.reverse()
  end

  @spec truncate(String.t(), Range.t()) :: String.t()
  def truncate(string, range \\ 0..90) do
    if String.length(string) > Enum.max(range) do
      String.slice(string, range) <> "…"
    else
      string
    end
  end

  @doc """
  Select an absolute timestamp appropriate for the provided state and format it.
  """
  @spec absolute_time(String.t(), Job.t()) :: String.t()
  def absolute_time(state, job) do
    case state do
      "executing" -> "Attempted At: #{truncate_sec(job.attempted_at)}"
      "completed" -> "Completed At: #{truncate_sec(job.completed_at)}"
      "retryable" -> "Retryable At: #{truncate_sec(job.scheduled_at)}"
      "available" -> "Available At: #{truncate_sec(job.scheduled_at)}"
      "scheduled" -> "Scheduled At: #{truncate_sec(job.scheduled_at)}"
      "discarded" -> "Discarded At: #{truncate_sec(job.completed_at || job.inserted_at)}"
    end
  end

  defp truncate_sec(datetime), do: NaiveDateTime.truncate(datetime, :second)

  @doc """
  Select a duration or distance in words based on the provided state.
  """
  @spec relative_time(String.t(), Job.t()) :: String.t()
  def relative_time(state, job) do
    case state do
      "attempted" -> Timing.to_words(job.relative_attempted_at)
      "completed" -> Timing.to_words(job.relative_completed_at)
      "discarded" -> Timing.to_words(job.relative_attempted_at || job.relative_inserted_at)
      "executing" -> Timing.to_duration(job.relative_attempted_at)
      "inserted" -> Timing.to_words(job.relative_inserted_at)
      _ -> Timing.to_words(job.relative_scheduled_at)
    end
  end
end
