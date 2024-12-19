defmodule Oban.Web.QueueQuery do
  @moduledoc false

  alias Oban.Met
  alias Oban.Web.{Queue, Search}

  @suggest_qualifier [
    {"nodes:", "host name", "nodes:machine@somehost"},
    {"modes:", "a concurrency mode such as global", "global"},
    {"stats:", "a status such as paused, global, etc.", "paused"}
  ]

  @suggest_mode [
    {"global_limit", "the queue is has a global limit", "global_limit"},
    {"rate_limit", "the queue is has a rate limit", "rate_limit"}
  ]

  @suggest_stat [
    {"paused", "the queue is paused on some nodes", "paused"},
    {"terminating", "the queue is shutting down", "terminating"}
  ]

  @known_qualifiers MapSet.new(@suggest_qualifier, fn {qualifier, _, _} -> qualifier end)

  # Searching

  @split_pattern ~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/

  def filterable, do: ~w(modes nodes stats)a

  def parse(terms) when is_binary(terms) do
    Search.parse(terms, &parse_term/1)
  end

  def suggest(terms, conf, _opts \\ []) do
    terms
    |> String.split(@split_pattern)
    |> List.last()
    |> to_string()
    |> case do
      "" ->
        @suggest_qualifier

      last ->
        case String.split(last, ":", parts: 2) do
          ["modes", frag] -> suggest_static(frag, @suggest_mode)
          ["nodes", frag] -> suggest_nodes(frag, conf)
          ["stats", frag] -> suggest_static(frag, @suggest_stat)
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

  defp suggest_nodes(fragment, conf) do
    conf.name
    |> Oban.Met.labels("node")
    |> Search.restrict_suggestions(fragment)
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

  defp parse_term("nodes:" <> nodes) do
    {:nodes, String.split(nodes, ",")}
  end

  defp parse_term("modes:" <> modes) do
    {:modes, String.split(modes, ",")}
  end

  defp parse_term("stats:" <> stats) do
    {:stats, String.split(stats, ",")}
  end

  defp parse_term(_term), do: {:none, ""}

  # Querying

  def all_queues(params, %{name: name}) do
    {sort_by, sort_dir} = atomize_sort(params)

    conditions = Map.take(params, filterable())

    counts = %{
      available: Met.latest(name, :full_count, group: "queue", filters: [state: "available"]),
      executing: Met.latest(name, :full_count, group: "queue", filters: [state: "executing"])
    }

    name
    |> Met.checks()
    |> Enum.group_by(& &1["queue"])
    |> Enum.map(&new(&1, counts))
    |> Enum.filter(&filter(&1, conditions))
    |> Enum.sort_by(&order(&1, sort_by), sort_dir)
  end

  defp new({name, checks}, counts) do
    counts = Map.new(counts, fn {state, counts} -> {state, Map.get(counts, name, 0)} end)

    struct!(Queue, %{name: name, checks: checks, counts: counts})
  end

  defp atomize_sort(%{sort_by: sby, sort_dir: dir}) do
    {String.to_existing_atom(sby), String.to_existing_atom(dir)}
  end

  defp atomize_sort(_params), do: {:name, :asc}

  # Filtering

  defp filter(_row, conditions) when conditions == %{}, do: true

  defp filter(row, conditions) when is_map(conditions) do
    Enum.all?(conditions, &filter(row, &1))
  end

  defp filter(%{checks: checks}, {:nodes, nodes}) do
    Enum.any?(checks, &(&1["node"] in nodes))
  end

  defp filter(queue, {:modes, modes}) do
    Enum.all?(modes, fn
      "global_limit" -> Queue.global_limit?(queue)
      "rate_limit" -> Queue.rate_limit?(queue)
    end)
  end

  defp filter(queue, {:stats, stats}) do
    Enum.all?(stats, fn
      "paused" -> Queue.any_paused?(queue)
      "terminating" -> Queue.terminating?(queue)
    end)
  end

  # Sorting

  defp order(%{counts: counts}, :avail) do
    Map.get(counts, "available", 0)
  end

  defp order(%{counts: counts}, :exec) do
    Map.get(counts, "executing", 0)
  end

  defp order(queue, :local) do
    Queue.local_limit(queue)
  end

  defp order(queue, :global) do
    Queue.global_limit(queue)
  end

  defp order(%{name: name}, :name), do: name

  defp order(%{checks: checks}, :nodes) do
    length(checks)
  end

  defp order(%{checks: checks}, :rate_limit) do
    checks
    |> Enum.map(&get_in(&1, ["rate_limit", "windows"]))
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
    |> Enum.reduce(0, &(&1["curr_count"] + &1["prev_count"] + &2))
  end

  defp order(%{checks: checks}, :started) do
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
