defmodule Oban.Web.Plugins.StatsTest do
  use Oban.Web.DataCase

  alias Oban.Web.Plugins.Stats

  @name Oban.StatsTest
  @opts [repo: Repo, name: @name, plugins: [{Stats, interval: 10}]]

  test "node and queue stats aren't tracked without an active connection" do
    insert_job!(queue: :alpha, state: "available")

    start_supervised_oban!(@opts)

    assert Stats.all_gossip(@name) == []
    assert Stats.all_counts(@name) == []

    stop_supervised!(@name)
  end

  test "updating node queue stats after activation" do
    with_activated(fn ->
      gossip(name: @name, node: "web.1", queue: "alpha", limit: 4, paused: false, running: [])
      gossip(name: @name, node: "web.2", queue: "alpha", limit: 4, paused: false, running: [])
      gossip(name: @name, node: "web.1", queue: "gamma", limit: 5, paused: true, running: [])
      gossip(name: @name, node: "web.2", queue: "gamma", limit: 5, paused: false, running: [1])
      gossip(name: @name, node: "web.2", queue: "delta", limit: 9, paused: false, running: [])

      nodes = Stats.all_gossip(@name)

      assert_in(nodes, %{"node" => "web.1", "limit" => 5})
      assert_in(nodes, %{"node" => "web.2", "limit" => 9})
    end)
  end

  test "updating counts after activation" do
    insert_job!(%{}, queue: :alpha, state: "available")
    insert_job!(%{}, queue: :gamma, state: "available")
    insert_job!(%{}, queue: :gamma, state: "scheduled")

    with_activated(fn ->
      counts = Stats.all_counts(@name)

      assert_in(counts, %{"name" => "alpha", "available" => 1, "completed" => 0})
      assert_in(counts, %{"name" => "gamma", "available" => 1, "scheduled" => 1})

      insert_job!(%{}, queue: :alpha, state: "completed")
      insert_job!(%{}, queue: :gamma, state: "completed")

      wait_for_refresh()

      counts = Stats.all_counts(@name)

      assert_in(counts, %{"name" => "alpha", "completed" => 1})
      assert_in(counts, %{"name" => "gamma", "completed" => 1})
    end)
  end

  test "clearing older cached values on refresh" do
    insert_job!(%{}, queue: :alpha, state: "executing")
    insert_job!(%{}, queue: :gamma, state: "available")

    with_activated(fn ->
      gossip(name: @name, node: "web.1", queue: "alpha", running: [])
      gossip(name: @name, node: "web.1", queue: "gamma", running: [])

      counts = Stats.all_counts(@name)

      assert_in(counts, %{"name" => "alpha", "executing" => 1})
      assert_in(counts, %{"name" => "gamma", "available" => 1})

      Repo.delete_all(Job)

      wait_for_refresh()

      assert [] = Stats.all_counts(@name)
    end)
  end

  test "refreshing stops when all activated nodes disconnect" do
    start_supervised_oban!(@opts)

    insert_job!(%{}, queue: :alpha, state: "available")

    fn -> :ok = Stats.activate(@name) end
    |> Task.async()
    |> Task.await()

    insert_job!(queue: :alpha, state: "available")

    wait_for_refresh()

    assert_in(Stats.all_counts(@name), %{"name" => "alpha", "available" => 1})

    stop_supervised!(@name)
  end

  test "empty results are returned when an ets table isn't available" do
    assert Stats.all_gossip(@name) == []
    assert Stats.all_counts(@name) == []

    Registry.put_meta(Oban.Registry, {@name, {:plugin, Stats}}, make_ref())

    assert Stats.all_gossip(@name) == []
    assert Stats.all_counts(@name) == []
  end

  # The refresh rate is 10ms, after 20ms the values still should not have refreshed
  defp wait_for_refresh do
    [repo: _, name: _, plugins: [{Stats, interval: interval}]] = @opts

    Process.sleep(interval * 2)
  end

  defp with_activated(fun) do
    start_supervised_oban!(@opts)

    :ok = Stats.activate(@name)

    fun.()

    stop_supervised!(@name)
  end

  defp assert_in(list, payload) do
    keys = Map.keys(payload)
    vals = Enum.map(list, &Map.take(&1, keys))

    assert payload in vals
  end
end
