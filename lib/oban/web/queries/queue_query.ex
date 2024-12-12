defmodule Oban.Web.QueueQuery do
  @moduledoc false

  alias Oban.Met
  alias Oban.Web.Search

  defstruct [:name, :checks, :counts]

  @suggest_qualifier [
    {"global:", "the queue has a global limit"},
    {"paused:", "whether queue instances are paused or not", "any"}
  ]

  @suggest_paused [
    {"all", "the queue on all nodes are paused", "paused:all"},
    {"any", "the queue on some notes is paused", "paused:any"},
    {"none", "the queue isn't paused on any nodes", "paused:none"},
  ]

  @known_qualifiers MapSet.new(@suggest_qualifier, fn {qualifier, _, _} -> qualifier end)

  # Searching

  @split_pattern ~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/

  def filterable, do: ~w(paused)a

  def parse(terms) when is_binary(terms) do
    Search.parse(terms, &parse_term/1)
  end

  def suggest(terms, _conf, _opts \\ []) do
    terms
    |> String.split(@split_pattern)
    |> List.last()
    |> to_string()
    |> case do
      "" ->
        @suggest_qualifier

      last ->
        case String.split(last, ":", parts: 2) do
          ["paused", frag] -> suggest_static(frag, @suggest_paused)
          [frag] -> suggest_static(frag, @suggest_qualifier)
          _ -> []
        end
    end
  end

  defp suggest_static(fragment, possibilities) do
    for {field, _, _} = suggest <- possibilities,
        String.starts_with?(field, fragment),
        do: suggest
  end

  def append(terms, choice) do
    Search.append(terms, choice, @known_qualifiers)
  end

  def complete(terms, conf) do
    case suggest(terms, conf) do
      [] ->
        terms

      [{match, _, _} | _] ->
        append(terms, match)
    end
  end

  defp parse_term("paused:" <> boolean) do
    {:paused, boolean}
  end

  defp parse_term(_term), do: {:none, ""}

  # Querying

  def all_queues(params, conf) do
    {sort_by, sort_dir} = atomize_sort(params)

    conditions = Map.take(params, ~w(paused)a)
    counts = Met.latest(conf.name, :full_count, group: "queue", filters: [state: "available"])

    conf.name
    |> Met.checks()
    |> Enum.group_by(& &1["queue"])
    |> Enum.map(&new(&1, counts))
    |> Enum.filter(&filter(&1, conditions))
    |> Enum.sort_by(&table_sort(&1, sort_by), sort_dir)
  end

  defp new({name, checks}, counts) do
    struct!(__MODULE__, %{name: name, checks: checks, counts: Map.get(counts, name, 0)})
  end

  # Filtering

  defp filter(_row, conditions) when conditions == %{}, do: true

  defp filter(row, conditions) when is_map(conditions) do
    Enum.all?(conditions, &filter(row, &1)
  end

  defp filter(row, {:paused, mode}) do
    # check thing here
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
