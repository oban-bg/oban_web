defmodule Oban.Web.Timing do
  @moduledoc false

  @empty_time "-"

  @doc """
  Snap unix time to an even value for a given increment.

      iex> Oban.Web.Timing.snap(1685707957, 1)
      1685707957

      iex> Oban.Web.Timing.snap(1685707957, 5)
      1685707960

      iex> Oban.Web.Timing.snap(1685707957, 30)
      1685707980
  """
  def snap(unix, step) when rem(unix, step) == 0, do: unix
  def snap(unix, step), do: snap(unix + 1, step)

  @doc """
  Format ellapsed seconds into a timer format of "MM:SS" or "HH:MM:SS".

      iex> Oban.Web.Timing.to_duration(0)
      "00:00"

      iex> Oban.Web.Timing.to_duration(5)
      "00:05"

      iex> Oban.Web.Timing.to_duration(-5)
      "00:05"

      iex> Oban.Web.Timing.to_duration(60)
      "01:00"

      iex> Oban.Web.Timing.to_duration(65)
      "01:05"

      iex> Oban.Web.Timing.to_duration(7199)
      "01:59:59"
  """
  def to_duration(ellapsed) when is_integer(ellapsed) do
    ellapsed = abs(ellapsed)
    seconds = Integer.mod(ellapsed, 60)
    minutes = ellapsed |> Integer.mod(3_600) |> div(60)
    hours = div(ellapsed, 3_600)

    parts = [minutes, seconds]
    parts = if hours > 0, do: [hours | parts], else: parts

    Enum.map_join(parts, ":", &pad/1)
  end

  @doc """
  Format elapsed seconds with trailing milliseconds.

      iex> Oban.Web.Timing.to_duration(0, :millisecond)
      "00:00.000"

      iex> Oban.Web.Timing.to_duration(5, :millisecond)
      "00:00.005"

      iex> Oban.Web.Timing.to_duration(-5, :millisecond)
      "00:00.005"

      iex> Oban.Web.Timing.to_duration(61030, :millisecond)
      "01:01.030"

      iex> Oban.Web.Timing.to_duration(61930, :millisecond)
      "01:01.930"
  """
  def to_duration(ellapsed, :millisecond) do
    milliseconds =
      ellapsed
      |> abs()
      |> Integer.mod(1000)
      |> pad(3)

    ellapsed
    |> div(1000)
    |> to_duration()
    |> Kernel.<>(".#{milliseconds}")
  end

  @doc """
  Format ellapsed seconds into a wordy format, based on "distance of time in words".

      iex> Oban.Web.Timing.to_words(0)
      "now"

      iex> Oban.Web.Timing.to_words(1)
      "in 1s"

      iex> Oban.Web.Timing.to_words(-1)
      "1s ago"

      iex> Oban.Web.Timing.to_words(-5)
      "5s ago"

      iex> Oban.Web.Timing.to_words(60)
      "in 1m"

      iex> Oban.Web.Timing.to_words(121)
      "in 2m"

      iex> Oban.Web.Timing.to_words(-60 * 60)
      "1h ago"

      iex> Oban.Web.Timing.to_words(60 * 60)
      "in 1h"

      iex> Oban.Web.Timing.to_words((60 * 60 * 24) - 1)
      "in 23h"

      iex> Oban.Web.Timing.to_words(60 * 60 * 24)
      "in 1d"

      iex> Oban.Web.Timing.to_words(60 * 60 * 24 * 5)
      "in 5d"

      iex> Oban.Web.Timing.to_words(60 * 60 * 24 * 30)
      "in 1mo"

      iex> Oban.Web.Timing.to_words(60 * 60 * 24 * 30 * 5)
      "in 5mo"

      iex> Oban.Web.Timing.to_words(60 * 60 * 24 * 365)
      "in 1yr"

      iex> Oban.Web.Timing.to_words(60 * 60 * 24 * 365 * 2)
      "in 2yr"

  The `:relative` option controls whether an "in" or "ago" modifier is added:

      iex> Oban.Web.Timing.to_words(1, relative: false)
      "1s"

      iex> Oban.Web.Timing.to_words(-1, relative: false)
      "1s"
  """
  def to_words(ellapsed, opts \\ [relative: true]) when is_integer(ellapsed) do
    distance =
      case abs(ellapsed) do
        0 -> "now"
        n when n in 1..59 -> "#{n}s"
        n when n in 60..3_599 -> "#{div(n, 60)}m"
        n when n in 3_600..86_399 -> "#{div(n, 3_600)}h"
        n when n in 86_400..2_591_999 -> "#{div(n, 86_400)}d"
        n when n in 2_592_000..31_535_999 -> "#{div(n, 2_592_000)}mo"
        n -> "#{div(n, 31_536_000)}yr"
      end

    cond do
      not opts[:relative] -> distance
      ellapsed < 0 -> "#{distance} ago"
      ellapsed > 0 -> "in #{distance}"
      true -> distance
    end
  end

  @doc """
  Calculate the amount of time a job waited between availability and execution.

      iex> Oban.Web.Timing.queue_time(%{attempted_at: nil})
      "-"

      iex> at = DateTime.utc_now()
      ...> Oban.Web.Timing.queue_time(%{attempted_at: at, inserted_at: at, scheduled_at: at})
      "00:00.000"

      iex> at_at = DateTime.utc_now()
      ...> sc_at = DateTime.add(at_at, -60)
      ...> Oban.Web.Timing.queue_time(%{attempted_at: at_at, inserted_at: sc_at, scheduled_at: sc_at})
      "01:00.000"

      iex> at_at = DateTime.utc_now()
      ...> sc_at = DateTime.add(at_at, -60)
      ...> Oban.Web.Timing.queue_time(%{attempted_at: at_at, inserted_at: sc_at, scheduled_at: sc_at})
      "01:00.000"

      iex> at_at = DateTime.utc_now()
      ...> in_at = DateTime.add(at_at, -60)
      ...> sc_at = DateTime.add(at_at, -90)
      ...> Oban.Web.Timing.queue_time(%{attempted_at: at_at, inserted_at: in_at, scheduled_at: sc_at})
      "01:00.000"
  """
  def queue_time(%{attempted_at: nil}), do: @empty_time

  def queue_time(job) do
    scheduled_or_inserted =
      if DateTime.compare(job.scheduled_at, job.inserted_at) == :gt do
        job.scheduled_at
      else
        job.inserted_at
      end

    job.attempted_at
    |> DateTime.diff(scheduled_or_inserted, :millisecond)
    |> to_duration(:millisecond)
  end

  @doc """
  Calculate the amount of time a job executed before completing or discarded.

      iex> Oban.Web.Timing.run_time(%{attempted_at: nil})
      "-"

      iex> Oban.Web.Timing.run_time(%{completed_at: nil, discarded_at: nil})
      "-"

      iex> at = DateTime.utc_now()
      ...> Oban.Web.Timing.run_time(%{attempted_at: at, completed_at: at})
      "00:00.000"

      iex> at_at = DateTime.utc_now()
      ...> co_at = DateTime.add(at_at, -60)
      ...> Oban.Web.Timing.run_time(%{attempted_at: at_at, completed_at: co_at})
      "01:00.000"

      iex> at_at = DateTime.utc_now()
      ...> di_at = DateTime.add(at_at, -60)
      ...> Oban.Web.Timing.run_time(%{attempted_at: at_at, completed_at: nil, discarded_at: di_at})
      "01:00.000"
  """
  def run_time(%{attempted_at: nil}), do: @empty_time
  def run_time(%{completed_at: nil, discarded_at: nil}), do: @empty_time

  def run_time(job) do
    finished_at = job.completed_at || job.discarded_at

    job.attempted_at
    |> DateTime.diff(finished_at, :millisecond)
    |> to_duration(:millisecond)
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
  Convert a stringified timestamp (i.e. from an error) into a relative time.
  """
  def iso8601_to_words(iso8601, now \\ NaiveDateTime.utc_now()) do
    {:ok, datetime} = NaiveDateTime.from_iso8601(iso8601)

    datetime
    |> NaiveDateTime.diff(now)
    |> to_words()
  end

  defp pad(time, places \\ 2) do
    time
    |> to_string()
    |> String.pad_leading(places, "0")
  end
end
