defmodule Oban.Web.Helpers.QueueHelper do
  @moduledoc """
  Helpers for queue formatting and operations.
  """

  alias Oban.Web.Timing

  @doc """
  Find and format the oldest starting time in a collection of gossip messages.
  """
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
end
