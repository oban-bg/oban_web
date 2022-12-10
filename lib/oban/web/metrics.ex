defmodule Oban.Web.Metrics do
  @moduledoc false

  alias Oban.Met

  @states ~w(available cancelled completed discarded executing retryable scheduled)

  @doc """
  Fetch all checks stored by Met.
  """
  def checks(oban_name), do: Met.checks(oban_name)

  @doc """
  Return timeseries data with values and labels grouped by timestamp.

      {ts, [{value, label}, {value, label}]}
      {ts, [{value, label}, {value, label}]}
      {ts, [{value, label}, {value, label}]}

  The slice is automatically interpolated to fill any gaps.
  """
  def timeslice(oban_name, series, opts) do
    oban_name
    |> Met.timeslice(series, opts)
    |> Enum.group_by(&elem(&1, 0), &Tuple.delete_at(&1, 0))
    |> Enum.sort(:desc)

    # this is where we apply the padding to fill out the time
  end

  @doc """
  Retrieve gauges for all job states (which is typically all gauges).

  This mimics the output of the legacy `Stats.all_counts/1` function.
  """
  @spec state_counts(Oban.name()) :: [map()]
  def state_counts(oban_name) do
    base = Map.new(@states, &{&1, 0})

    @states
    |> Enum.map(&{&1, Met.latest(oban_name, &1, group: "queue")})
    |> Enum.reduce(%{}, fn {state, queues}, acc ->
      Enum.reduce(queues, acc, fn {queue, value}, sub_acc ->
        Map.update(sub_acc, queue, %{base | state => value}, &Map.put(&1, state, value))
      end)
    end)
    |> Enum.map(fn {queue, counts} -> Map.put(counts, "name", queue) end)
  end

  @doc """
  Retrieve :executing guages for active nodes.
  """
  @spec node_counts(Oban.name()) :: [map()]
  def node_counts(oban_name) do
    Met.latest(oban_name, :executing, group: "node")
  end
end
