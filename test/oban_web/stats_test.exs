defmodule ObanWeb.StatsTest do
  use ObanWeb.DataCase

  import Oban.Notifier, only: [gossip: 0, insert: 0, signal: 0, update: 0]

  alias Oban.{Beat, Job}
  alias ObanWeb.Stats

  @name __MODULE__
  @opts [name: @name, repo: ObanWeb.Repo, update_threshold: 10]

  def for_queues do
    @name
    |> Stats.for_queues()
    |> Map.new()
  end

  def for_states do
    @name
    |> Stats.for_states()
    |> Map.new()
  end

  def for_nodes do
    @name
    |> Stats.for_nodes()
    |> Map.new()
  end

  test "starting with queues set to false or nil simply exits" do
    assert :ignore = Stats.start_link(name: @name, queues: false)
    assert :ignore = Stats.start_link(name: @name, queues: nil)
  end

  test "initializing with current state and queue counts" do
    insert_job!(queue: :alpha, state: "available")
    insert_job!(queue: :alpha, state: "executing")
    insert_job!(queue: :gamma, state: "available")
    insert_job!(queue: :gamma, state: "scheduled")
    insert_job!(queue: :gamma, state: "completed")

    insert_beat!(node: "web.1", queue: "alpha", limit: 4)
    insert_beat!(node: "web.2", queue: "alpha", limit: 4)
    insert_beat!(node: "web.1", queue: "gamma", limit: 5)
    insert_beat!(node: "web.2", queue: "gamma", limit: 5)
    insert_beat!(node: "web.2", queue: "delta", limit: 9)

    start_supervised!({Stats, @opts})

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => %{avail: 1, execu: 1, limit: 8},
               "delta" => %{avail: 0, execu: 0, limit: 9},
               "gamma" => %{avail: 1, execu: 0, limit: 10}
             }

      assert for_states() == %{
               "executing" => %{count: 1},
               "available" => %{count: 2},
               "scheduled" => %{count: 1},
               "retryable" => %{count: 0},
               "discarded" => %{count: 0},
               "completed" => %{count: 1}
             }
    end)

    stop_supervised(Stats)
  end

  test "insert notifications modify the cached values" do
    insert_beat!(node: "web.1", queue: "alpha", limit: 1)
    insert_beat!(node: "web.1", queue: "gamma", limit: 1)
    insert_beat!(node: "web.1", queue: "delta", limit: 1)

    {:ok, pid} = start_supervised({Stats, @opts})

    notify(pid, insert(), queue: :alpha, state: "available")
    notify(pid, insert(), queue: :gamma, state: "available")
    notify(pid, insert(), queue: :delta, state: "scheduled")

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => %{avail: 1, execu: 0, limit: 1},
               "delta" => %{avail: 0, execu: 0, limit: 1},
               "gamma" => %{avail: 1, execu: 0, limit: 1}
             }

      assert for_states() == %{
               "executing" => %{count: 0},
               "available" => %{count: 2},
               "scheduled" => %{count: 1},
               "retryable" => %{count: 0},
               "discarded" => %{count: 0},
               "completed" => %{count: 0}
             }
    end)

    stop_supervised(Stats)
  end

  test "update notifications modify the cached values" do
    insert_beat!(node: "web.1", queue: "alpha", limit: 1)
    insert_beat!(node: "web.1", queue: "gamma", limit: 1)
    insert_beat!(node: "web.1", queue: "delta", limit: 1)

    {:ok, pid} = start_supervised({Stats, @opts})

    insert_job!(queue: :alpha, state: "available")
    insert_job!(queue: :alpha, state: "executing")
    insert_job!(queue: :gamma, state: "available")
    insert_job!(queue: :gamma, state: "scheduled")
    insert_job!(queue: :delta, state: "executing")

    # Sleep longer than the `update_threshold` to force a refresh
    Process.sleep(15)

    # A single update is enough to trigger a refresh, the queue and states don't matter.
    notify(pid, update(), queue: :alpha, old_state: "available", new_state: "executing")

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => %{avail: 1, execu: 1, limit: 1},
               "delta" => %{avail: 0, execu: 1, limit: 1},
               "gamma" => %{avail: 1, execu: 0, limit: 1}
             }

      assert for_states() == %{
               "executing" => %{count: 2},
               "available" => %{count: 2},
               "scheduled" => %{count: 1},
               "retryable" => %{count: 0},
               "discarded" => %{count: 0},
               "completed" => %{count: 0}
             }
    end)

    stop_supervised(Stats)
  end

  test "gossip notifications modify the cached values" do
    {:ok, pid} = start_supervised({Stats, @opts})

    notify(pid, gossip(), count: 2, limit: 5, node: "worker.1", paused: false, queue: :alpha)
    notify(pid, gossip(), count: 1, limit: 4, node: "worker.2", paused: false, queue: :alpha)
    notify(pid, gossip(), count: 3, limit: 5, node: "worker.1", paused: false, queue: :gamma)
    notify(pid, gossip(), count: 1, limit: 4, node: "worker.2", paused: false, queue: :gamma)
    notify(pid, gossip(), count: 1, limit: 5, node: "worker.1", paused: false, queue: :delta)
    notify(pid, gossip(), count: 1, limit: 4, node: "worker.2", paused: false, queue: :delta)

    with_backoff(fn ->
      assert for_nodes() == %{
               "worker.1" => %{count: 6, limit: 15},
               "worker.2" => %{count: 3, limit: 12}
             }
    end)

    notify(pid, gossip(), count: 1, limit: 5, node: "worker.1", paused: false, queue: :alpha)
    notify(pid, gossip(), count: 0, limit: 5, node: "worker.2", paused: false, queue: :alpha)
    notify(pid, gossip(), count: 4, limit: 5, node: "worker.1", paused: false, queue: :gamma)
    notify(pid, gossip(), count: 2, limit: 5, node: "worker.2", paused: false, queue: :gamma)
    notify(pid, gossip(), count: 0, limit: 5, node: "worker.1", paused: false, queue: :delta)
    notify(pid, gossip(), count: 2, limit: 5, node: "worker.2", paused: false, queue: :delta)

    with_backoff(fn ->
      assert for_nodes() == %{
               "worker.1" => %{count: 5, limit: 15},
               "worker.2" => %{count: 4, limit: 15}
             }
    end)

    stop_supervised(Stats)
  end

  test "counts are refreshed from the database to prevent drift" do
    {:ok, pid} = start_supervised({Stats, @opts})

    insert_beat!(node: "web.1", queue: "alpha", limit: 1)
    insert_beat!(node: "web.1", queue: "gamma", limit: 1)
    insert_beat!(node: "web.1", queue: "delta", limit: 1)

    insert_job!(queue: :gamma, state: "available")
    insert_job!(queue: :delta, state: "available")

    send(pid, :refresh)

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => %{avail: 0, execu: 0, limit: 1},
               "delta" => %{avail: 1, execu: 0, limit: 1},
               "gamma" => %{avail: 1, execu: 0, limit: 1}
             }
    end)
  end

  test "signal notifications modify the tracked queue limits" do
    insert_beat!(node: "web.1", queue: "alpha", limit: 1)
    insert_beat!(node: "web.1", queue: "gamma", limit: 1)
    insert_beat!(node: "web.1", queue: "delta", limit: 1)

    {:ok, pid} = start_supervised({Stats, @opts})

    notify(pid, signal(), action: :scale, queue: :gamma, scale: 7)
    notify(pid, signal(), action: :scale, queue: :delta, scale: 4)

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => %{avail: 0, execu: 0, limit: 1},
               "delta" => %{avail: 0, execu: 0, limit: 4},
               "gamma" => %{avail: 0, execu: 0, limit: 7}
             }
    end)

    stop_supervised(Stats)
  end

  defp insert_job!(opts) do
    opts =
      opts
      |> Keyword.put_new(:queue, :default)
      |> Keyword.put_new(:worker, FakeWorker)

    %{}
    |> Job.new(opts)
    |> Repo.insert!()
  end

  defp insert_beat!(opts) do
    opts
    |> Map.new()
    |> Map.put_new(:inserted_at, seconds_ago(1))
    |> Map.put_new(:limit, 1)
    |> Map.put_new(:nonce, "aaaaaaaa")
    |> Map.put_new(:started_at, seconds_ago(300))
    |> Beat.new()
    |> Repo.insert!()
  end

  defp notify(pid, event, payload) do
    payload =
      payload
      |> Map.new()
      |> Jason.encode!()
      |> Jason.decode!()

    send(pid, {:notification, event, payload})
  end

  defp seconds_ago(seconds) do
    DateTime.add(DateTime.utc_now(), -seconds)
  end
end
