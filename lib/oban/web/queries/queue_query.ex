defmodule Oban.Web.QueueQuery do
  @moduledoc false

  use Oban.Web.Queryable

  alias Oban.Met
  alias Oban.Web.Queue

  @suggest_mode [
    {"global_limit", "the queue has a global limit", "global_limit"},
    {"rate_limit", "the queue has a rate limit", "rate_limit"}
  ]

  @suggest_stat [
    {"paused", "the queue is paused on some nodes", "paused"},
    {"terminating", "the queue is shutting down", "terminating"}
  ]

  # Searching

  @impl Queryable
  def qualifiers do
    [
      modes: [
        desc: "a concurrency mode such as global",
        example: "modes:global_limit",
        suggest: @suggest_mode
      ],
      nodes: [
        desc: "host name",
        example: "nodes:machine@somehost",
        suggest: &suggest_nodes/2
      ],
      stats: [
        desc: "a status such as paused or terminating",
        example: "stats:paused",
        suggest: @suggest_stat
      ]
    ]
  end

  defp suggest_nodes(frag, conf) do
    conf.name
    |> Met.labels("node")
    |> Search.restrict_suggestions(frag)
  end

  # Querying

  def all_queues(params, conf, counts \\ %{})

  def all_queues(params, %{name: name}, counts) do
    name
    |> Met.checks()
    |> Enum.group_by(& &1["queue"])
    |> Enum.map(&new(&1, counts))
    |> Queryable.refine(__MODULE__, params, default_sort: {:name, :asc})
  end

  defp new({name, checks}, counts) do
    counts = Map.new(counts, fn {state, counts} -> {state, Map.get(counts, name, 0)} end)

    struct!(Queue, %{name: name, checks: checks, counts: counts})
  end

  # Filtering

  @impl Queryable
  def filter(%{checks: checks}, {:nodes, nodes}) do
    Enum.any?(checks, &(&1["node"] in nodes))
  end

  def filter(queue, {:modes, modes}) do
    Enum.all?(modes, fn
      "global_limit" -> Queue.global_limit?(queue)
      "rate_limit" -> Queue.rate_limit?(queue)
    end)
  end

  def filter(queue, {:stats, stats}) do
    Enum.all?(stats, fn
      "paused" -> Queue.any_paused?(queue)
      "terminating" -> Queue.terminating?(queue)
    end)
  end

  # Sorting

  @impl Queryable
  def order(%{counts: counts}, :avail) do
    Map.get(counts, "available", 0)
  end

  def order(%{counts: counts}, :exec) do
    Map.get(counts, "executing", 0)
  end

  def order(queue, :local) do
    Queue.local_limit(queue)
  end

  def order(queue, :global) do
    Queue.global_limit(queue)
  end

  def order(%{name: name}, :name), do: name

  def order(%{checks: checks}, :nodes) do
    length(checks)
  end

  def order(%{checks: checks}, :rate_limit) do
    checks
    |> Enum.map(&get_in(&1, ["rate_limit", "windows"]))
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
    |> Enum.reduce(0, &(&1["curr_count"] + &1["prev_count"] + &2))
  end

  def order(%{checks: checks}, :started) do
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
