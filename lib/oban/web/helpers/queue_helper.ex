defmodule Oban.Web.Helpers.QueueHelper do
  @moduledoc false

  alias Oban.Web.{Queue, Timing}

  def executing_count(checks) do
    checks
    |> List.wrap()
    |> Enum.map(&length(&1["running"]))
    |> Enum.sum()
  end

  def started_at(%{checks: _} = queue) do
    queue
    |> Queue.started_at()
    |> Timing.to_words()
  end

  def started_at(checks) do
    %Queue{checks: checks}
    |> Queue.started_at()
    |> Timing.to_words()
  end
end
