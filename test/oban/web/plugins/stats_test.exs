defmodule Oban.Web.Plugins.StatsTest do
  use Oban.Web.DataCase

  alias Oban.Web.Plugins.Stats

  @name Oban.StatsTest
  @opts [repo: Repo, name: @name, plugins: [{Stats, interval: 10}]]

  test "node and queue stats aren't tracked without an active connection" do
    insert_job!(queue: :alpha, state: "available")

    start_supervised_oban!(@opts)

    assert for_nodes() == %{}
    assert for_queues() == %{}

    assert for_states() == %{
             "executing" => %{count: 0},
             "available" => %{count: 0},
             "scheduled" => %{count: 0},
             "retryable" => %{count: 0},
             "discarded" => %{count: 0},
             "cancelled" => %{count: 0},
             "completed" => %{count: 0}
           }

    stop_supervised!(@name)
  end

  test "updating node and queue stats after activation" do
    insert_job!(%{}, queue: :alpha, state: "available")
    insert_job!(%{}, queue: :alpha, state: "executing")
    insert_job!(%{}, queue: :gamma, state: "available")
    insert_job!(%{}, queue: :gamma, state: "scheduled")
    insert_job!(%{}, queue: :gamma, state: "completed")

    start_supervised_oban!(@opts)

    :ok = Stats.activate(@name)

    gossip(name: @name, node: "web.1", queue: "alpha", limit: 4, paused: false, running: [])
    gossip(name: @name, node: "web.2", queue: "alpha", limit: 4, paused: false, running: [])
    gossip(name: @name, node: "web.1", queue: "gamma", limit: 5, paused: true, running: [])
    gossip(name: @name, node: "web.2", queue: "gamma", limit: 5, paused: false, running: [1])
    gossip(name: @name, node: "web.2", queue: "delta", limit: 9, paused: false, running: [])

    assert for_nodes() == %{
             "Oban.StatsTest/web.1" => %{count: 0, limit: 9},
             "Oban.StatsTest/web.2" => %{count: 1, limit: 18}
           }

    assert for_queues() == %{
             "alpha" => %{avail: 1, execu: 1, limit: 8, local: 4, pause: false},
             "delta" => %{avail: 0, execu: 0, limit: 9, local: 9, pause: false},
             "gamma" => %{avail: 1, execu: 0, limit: 10, local: 5, pause: true}
           }

    assert for_states() == %{
             "executing" => %{count: 1},
             "available" => %{count: 2},
             "scheduled" => %{count: 1},
             "retryable" => %{count: 0},
             "discarded" => %{count: 0},
             "cancelled" => %{count: 0},
             "completed" => %{count: 1}
           }

    stop_supervised!(@name)
  end

  test "refreshing stops when all activated nodes disconnect" do
    start_supervised_oban!(@opts)

    insert_job!(%{}, queue: :alpha, state: "available")

    fn -> :ok = Stats.activate(@name) end
    |> Task.async()
    |> Task.await()

    insert_job!(queue: :alpha, state: "available")

    # The refresh rate is 10ms, after 20ms the values still should not have refreshed
    Process.sleep(20)

    assert for_queues() == %{"alpha" => %{avail: 1, execu: 0, limit: 0, local: 0, pause: true}}

    stop_supervised!(@name)
  end

  defp for_nodes, do: @name |> Stats.for_nodes() |> Map.new()
  defp for_queues, do: @name |> Stats.for_queues() |> Map.new()
  defp for_states, do: @name |> Stats.for_states() |> Map.new()
end
