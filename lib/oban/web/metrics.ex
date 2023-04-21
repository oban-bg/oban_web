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
end
