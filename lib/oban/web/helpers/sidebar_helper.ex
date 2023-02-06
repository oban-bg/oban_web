defmodule Oban.Web.Helpers.SidebarHelper do
  @moduledoc false

  import Oban.Web.Helpers, only: [node_name: 2]

  alias Oban.Met

  @ordered_states ~w(executing available scheduled retryable cancelled discarded completed)

  def nodes(oban_name) do
    counts = Met.latest(oban_name, :executing, group: "node")

    limits =
      oban_name
      |> Met.checks()
      |> Enum.reduce(%{}, fn %{"name" => name} = check, acc ->
        limit = check["limit"] || check["local_limit"]

        Map.update(acc, name, limit, &(&1 + limit))
      end)

    counts
    |> Enum.sort()
    |> Enum.map(fn {node, exec} ->
      %{name: node_name(oban_name, node), count: exec, limit: Map.get(limits, node, 0)}
    end)
  end

  def states(oban_name) do
    Enum.map(@ordered_states, fn state ->
      count =
        oban_name
        |> Met.latest(state)
        |> Map.get("all", 0)

      %{name: state, count: count}
    end)
  end

  def queues(oban_name) do
    checks = Met.checks(oban_name)
    avail_counts = Met.latest(oban_name, :available, group: "queue")
    execu_counts = Met.latest(oban_name, :executing, group: "queue")

    total_limits =
      Enum.reduce(checks, %{}, fn payload, acc ->
        case payload_limit(payload) do
          {:global, limit} ->
            Map.put(acc, payload["queue"], limit)

          {:local, limit} ->
            Map.update(acc, payload["queue"], limit, &(&1 + limit))
        end
      end)

    pause_states =
      Enum.reduce(checks, %{}, fn %{"paused" => paused, "queue" => queue}, acc ->
        Map.update(acc, queue, paused, &(&1 or paused))
      end)

    [avail_counts, execu_counts, total_limits]
    |> Enum.flat_map(&Map.keys/1)
    |> :lists.usort()
    |> Enum.map(fn queue ->
      %{
        name: queue,
        avail: Map.get(avail_counts, queue, 0),
        execu: Map.get(execu_counts, queue, 0),
        limit: Map.get(total_limits, queue, 0),
        paused?: Map.get(pause_states, queue, true),
        global?: Enum.any?(checks, &(&1["queue"] == queue and is_map(&1["global_limit"]))),
        rate_limited?: Enum.any?(checks, &(&1["queue"] == queue and is_map(&1["rate_limit"])))
      }
    end)
  end

  defp payload_limit(%{"global_limit" => %{"allowed" => limit}}), do: {:global, limit}
  defp payload_limit(%{"local_limit" => limit}) when is_integer(limit), do: {:local, limit}
  defp payload_limit(%{"limit" => limit}) when is_integer(limit), do: {:local, limit}
  defp payload_limit(_payload), do: {:local, 0}
end
