defmodule Oban.Web.Helpers.QueueHelper do
  @moduledoc false

  alias Oban.Web.Timing

  @doc """
  Find and format the oldest starting time in a collection of gossip messages.
  """
  def started_at([]), do: "-"

  def started_at(gossip) do
    gossip
    |> List.wrap()
    |> Enum.map(& &1["started_at"])
    |> Enum.map(&started_at_to_diff/1)
    |> Enum.max()
    |> Timing.to_words()
  end

  defp started_at_to_diff(started_at) do
    {:ok, date_time, _} = DateTime.from_iso8601(started_at)

    DateTime.diff(date_time, DateTime.utc_now())
  end

  @doc """
  Count all running jobs in a collection of gossip messages.
  """
  def executing_count(gossip) do
    gossip
    |> List.wrap()
    |> Enum.map(&length(&1["running"]))
    |> Enum.sum()
  end

  @doc """
  Extract the allowed value from a global limit.
  """
  def global_limit_to_words(gossip) do
    gossip
    |> Enum.map(& &1["global_limit"])
    |> Enum.filter(&is_map/1)
    |> List.first()
    |> case do
      %{"allowed" => allowed} -> allowed
      _ -> "-"
    end
  end

  @doc """
  Calculate the estimated rate limit as words.
  """
  def rate_limit_to_words(gossip) do
    gossip
    |> Enum.map(& &1["rate_limit"])
    |> Enum.reject(&is_nil/1)
    |> case do
      [head_limit | _rest] = rate_limits ->
        %{"allowed" => allowed, "period" => period, "window_time" => time} = head_limit

        {prev_total, curr_total} =
          rate_limits
          |> Enum.flat_map(& &1["windows"])
          |> Enum.reduce({0, 0}, fn %{"prev_count" => pcnt, "curr_count" => ccnt}, {pacc, cacc} ->
            {pacc + pcnt, cacc + ccnt}
          end)

        ellapsed = unix_now() - time_to_unix(time)
        weight = div(max(period - ellapsed, 0), period)
        remaining = prev_total * weight + curr_total

        period_in_words = Timing.to_words(period, relative: false)

        "#{remaining}/#{allowed} per #{period_in_words}"

      [] ->
        "-"
    end
  end

  defp unix_now, do: DateTime.to_unix(DateTime.utc_now(), :second)

  defp time_to_unix(unix) when is_integer(unix) do
    unix
  end

  defp time_to_unix(time) do
    Date.utc_today()
    |> DateTime.new!(Time.from_iso8601!(time))
    |> DateTime.to_unix(:second)
  end
end
