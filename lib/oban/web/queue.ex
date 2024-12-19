defmodule Oban.Web.Queue do
  @moduledoc false

  alias __MODULE__

  # A struct to encapsulate queues and filtering functions

  defstruct [:name, :checks, :counts]

  def local_limit(%Queue{checks: checks}) do
    Enum.reduce(checks, 0, &((&1["limit"] || &1["local_limit"]) + &2))
  end

  def global_limit(%Queue{checks: checks}) do
    Enum.find_value(checks, &get_in(&1, ["global_limit", "allowed"]))
  end

  def total_limit(%Queue{checks: checks}) do
    Enum.reduce(checks, 0, &total_limit/2)
  end

  defp total_limit(%{"global_limit" => %{"allowed" => limit}}, _total), do: limit
  defp total_limit(%{"local_limit" => limit}, total) when is_integer(limit), do: total + limit
  defp total_limit(%{"limit" => limit}, total) when is_integer(limit), do: total + limit
  defp total_limit(_payload, total), do: total

  def started_at(%Queue{checks: checks}) do
    checks
    |> List.wrap()
    |> Enum.map(& &1["started_at"])
    |> Enum.map(&started_at_to_diff/1)
    |> Enum.max()
  end

  defp started_at_to_diff(started_at) do
    {:ok, date_time, _} = DateTime.from_iso8601(started_at)

    DateTime.diff(date_time, DateTime.utc_now())
  end

  # Predicates

  def all_paused?(%Queue{checks: checks}) do
    Enum.all?(checks, & &1["paused"])
  end

  def any_paused?(%Queue{checks: checks}) do
    Enum.any?(checks, & &1["paused"])
  end

  def global_limit?(%Queue{checks: checks}) do
    Enum.any?(checks, &is_map(&1["global_limit"]))
  end

  def rate_limit?(%Queue{checks: checks}) do
    Enum.any?(checks, &is_map(&1["rate_limit"]))
  end

  def terminating?(%Queue{checks: checks}) do
    Enum.any?(checks, & &1["shutdown_started_at"])
  end
end
