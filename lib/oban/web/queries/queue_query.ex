defmodule Oban.Web.QueueQuery do
  @moduledoc false

  alias Oban.Met

  defstruct [:name, :checks, :counts]

  def all_queues(params, conf) do
    {sort_by, sort_dir} = atomize_sort(params)

    counts = Met.latest(conf.name, :full_count, group: "queue", filters: [state: "available"])

    conf.name
    |> Met.checks()
    |> Enum.group_by(& &1["queue"])
    |> Enum.map(&new(&1, counts))
    |> Enum.sort_by(&table_sort(&1, sort_by), sort_dir)
  end

  defp new({name, checks}, counts) do
    struct!(__MODULE__, %{name: name, checks: checks, counts: Map.get(counts, name, 0)})
  end

  # Sorting

  defp atomize_sort(%{sort_by: sby, sort_dir: dir}) do
    {String.to_existing_atom(sby), String.to_existing_atom(dir)}
  end

  defp table_sort(%{counts: counts}, :avail) do
    Map.get(counts, "available", 0)
  end

  defp table_sort(%{checks: checks}, :exec) do
    Enum.reduce(checks, 0, &(length(&1["running"]) + &2))
  end

  defp table_sort(%{checks: checks}, :local) do
    Enum.reduce(checks, 0, &((&1["limit"] || &1["local_limit"]) + &2))
  end

  defp table_sort(%{checks: checks}, :global) do
    total = for %{"local_limit" => limit} <- checks, reduce: 0, do: (acc -> acc + limit)

    Enum.find_value(checks, total, & &1["global_limit"])
  end

  defp table_sort(%{name: name}, :name), do: name

  defp table_sort(%{checks: checks}, :nodes) do
    checks
    |> Enum.uniq_by(& &1["node"])
    |> length()
  end

  defp table_sort(%{checks: checks}, :rate_limit) do
    checks
    |> Enum.map(&get_in(&1, ["rate_limit", "windows"]))
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
    |> Enum.reduce(0, &(&1["curr_count"] + &1["prev_count"] + &2))
  end

  defp table_sort(%{checks: checks}, :started) do
    started_at_to_diff = fn started_at ->
      {:ok, date_time, _} = DateTime.from_iso8601(started_at)

      DateTime.diff(date_time, DateTime.utc_now())
    end

    checks
    |> Enum.map(& &1["started_at"])
    |> Enum.map(started_at_to_diff)
    |> Enum.max()
  end
end
