defmodule Oban.Web.Helpers.SidebarHelper do
  @moduledoc false

  import Oban.Web.Helpers, only: [node_name: 2]

  alias Oban.Met

  @ordered_states ~w(executing available scheduled retryable cancelled discarded completed)

  def nodes(oban_name) do
    oban_name
    |> Met.checks()
    |> Enum.reduce(%{}, fn check, acc ->
      nname = node_name(check["node"], check["name"])
      count = length(check["running"])
      limit = check["local_limit"] || check["limit"]

      acc
      |> Map.put_new(nname, %{name: nname, count: 0, limit: 0})
      |> update_in([nname, :count], &(&1 + count))
      |> update_in([nname, :limit], &(&1 + limit))
    end)
    |> Map.values()
    |> Enum.sort_by(& &1.name)
  end

  def states(oban_name) do
    counts = Met.latest(oban_name, :full_count, group: "state")

    for state <- @ordered_states do
      %{name: state, count: Map.get(counts, state, 0)}
    end
  end

  def queues(oban_name) do
    avail_counts =
      Met.latest(oban_name, :full_count, group: "queue", filters: [state: "available"])

    execu_counts =
      Met.latest(oban_name, :full_count, group: "queue", filters: [state: "executing"])

    oban_name
    |> Met.checks()
    |> Enum.reduce(%{}, fn %{"queue" => queue} = check, acc ->
      empty = fn ->
        %{
          name: queue,
          avail: Map.get(avail_counts, queue, 0),
          execu: Map.get(execu_counts, queue, 0),
          limit: 0,
          paused?: false,
          global?: false,
          rate_limited?: false
        }
      end

      acc
      |> Map.put_new_lazy(queue, empty)
      |> update_in([queue, :limit], &check_limit(&1, check))
      |> update_in([queue, :global?], &(&1 or is_map(check["global_limit"])))
      |> update_in([queue, :rate_limited?], &(&1 or is_map(check["rate_limit"])))
      |> update_in([queue, :paused?], &(&1 or check["paused"]))
    end)
    |> Map.values()
    |> Enum.sort_by(& &1.name)
  end

  defp check_limit(_total, %{"global_limit" => %{"allowed" => limit}}), do: limit
  defp check_limit(total, %{"local_limit" => limit}) when is_integer(limit), do: total + limit
  defp check_limit(total, %{"limit" => limit}) when is_integer(limit), do: total + limit
  defp check_limit(total, _payload), do: total
end
