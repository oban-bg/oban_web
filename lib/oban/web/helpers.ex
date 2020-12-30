defmodule Oban.Web.Helpers do
  @moduledoc false

  alias Oban.Job
  alias Oban.Web.{Resolver, Timing}

  @doc """
  Check an action against the current access controls.
  """
  @spec can?(Resolver.access(), atom()) :: boolean()
  def can?(_action, :all), do: true
  def can?(_action, :read), do: false
  def can?(action, [_ | _] = opts), do: Keyword.get(opts, action, false)

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
      "available" -> "Available At: #{truncate_sec(job.scheduled_at)}"
      "cancelled" -> "Cancelled At: #{truncate_sec(job.cancelled_at)}"
      "completed" -> "Completed At: #{truncate_sec(job.completed_at)}"
      "discarded" -> "Discarded At: #{truncate_sec(job.discarded_at)}"
      "executing" -> "Attempted At: #{truncate_sec(job.attempted_at)}"
      "retryable" -> "Retryable At: #{truncate_sec(job.scheduled_at)}"
      "scheduled" -> "Scheduled At: #{truncate_sec(job.scheduled_at)}"
    end
  end

  defp truncate_sec(datetime), do: NaiveDateTime.truncate(datetime, :second)

  @doc """
  Select a duration or distance in words based on the provided state.
  """
  @spec relative_time(String.t(), Job.t()) :: String.t()
  def relative_time(state, job) do
    case state do
      "cancelled" -> Timing.to_words(job.relative_cancelled_at)
      "completed" -> Timing.to_words(job.relative_completed_at)
      "discarded" -> Timing.to_words(job.relative_discarded_at)
      "executing" -> Timing.to_duration(job.relative_attempted_at)
      _ -> Timing.to_words(job.relative_scheduled_at)
    end
  end

  @doc """
  Whether the job can be cancelled in its current state.
  """
  @spec cancelable?(Job.t()) :: boolean()
  def cancelable?(%Job{state: state}) do
    state in ~w(inserted scheduled available executing retryable)
  end

  @doc """
  Whether the job can be ran immediately in its current state.
  """
  @spec runnable?(Job.t()) :: boolean()
  def runnable?(%Job{state: state}) do
    state in ~w(inserted scheduled)
  end

  @doc """
  Whether the job can be retried in its current state.
  """
  @spec retryable?(Job.t()) :: boolean()
  def retryable?(%Job{state: state}) do
    state in ~w(completed retryable discarded cancelled)
  end

  @doc """
  Whether the job can be deleted in its current state.
  """
  @spec deletable?(Job.t()) :: boolean()
  def deletable?(%Job{state: state}), do: state != "executing"

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
  def formatted_tags(%Job{tags: []}), do: "..."
  def formatted_tags(%Job{tags: tags}), do: Enum.join(tags, ", ")
end
