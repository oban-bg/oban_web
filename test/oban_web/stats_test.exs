defmodule ObanWeb.StatsTest do
  use ObanWeb.DataCase

  import Oban.Notifier, only: [gossip: 0, insert: 0, signal: 0, update: 0]

  alias Oban.Job
  alias ObanWeb.Stats

  @name __MODULE__
  @opts [name: @name, queues: [alpha: 2, gamma: 3, delta: 2], repo: ObanWeb.Repo]

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

  test "initializing with current state and queue counts" do
    insert_job!(queue: :alpha, state: "available")
    insert_job!(queue: :alpha, state: "executing")
    insert_job!(queue: :gamma, state: "available")
    insert_job!(queue: :gamma, state: "scheduled")
    insert_job!(queue: :gamma, state: "completed")

    start_supervised!({Stats, @opts})

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => {1, 1, 2},
               "delta" => {0, 0, 2},
               "gamma" => {0, 1, 3}
             }

      assert for_states() == %{
               "executing" => 1,
               "available" => 2,
               "scheduled" => 1,
               "retryable" => 0,
               "discarded" => 0,
               "completed" => 1
             }
    end)

    stop_supervised(Stats)
  end

  test "insert notifications modify the cached values" do
    {:ok, pid} = start_supervised({Stats, @opts})

    notify(pid, insert(), queue: :alpha, state: "available")
    notify(pid, insert(), queue: :gamma, state: "available")
    notify(pid, insert(), queue: :delta, state: "scheduled")

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => {0, 1, 2},
               "delta" => {0, 0, 2},
               "gamma" => {0, 1, 3}
             }

      assert for_states() == %{
               "executing" => 0,
               "available" => 2,
               "scheduled" => 1,
               "retryable" => 0,
               "discarded" => 0,
               "completed" => 0
             }
    end)

    stop_supervised(Stats)
  end

  test "update notifications modify the cached values" do
    insert_job!(queue: :alpha, state: "available")
    insert_job!(queue: :gamma, state: "available")
    insert_job!(queue: :gamma, state: "scheduled")
    insert_job!(queue: :delta, state: "executing")

    {:ok, pid} = start_supervised({Stats, @opts})

    notify(pid, update(), queue: :alpha, old_state: "available", new_state: "executing")
    notify(pid, update(), queue: :gamma, old_state: "scheduled", new_state: "available")
    notify(pid, update(), queue: :gamma, old_state: "available", new_state: "executing")
    notify(pid, update(), queue: :delta, old_state: "executing", new_state: "completed")

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => {1, 0, 2},
               "delta" => {0, 0, 2},
               "gamma" => {1, 1, 3}
             }

      assert for_states() == %{
               "executing" => 2,
               "available" => 1,
               "scheduled" => 0,
               "retryable" => 0,
               "discarded" => 0,
               "completed" => 1
             }
    end)

    stop_supervised(Stats)
  end

  test "gossip notifications modify the cached values" do
    {:ok, pid} = start_supervised({Stats, @opts})

    notify(pid, gossip(), count: 2, limit: 5, node: "worker.1", paused: false, queue: :alpha)
    notify(pid, gossip(), count: 1, limit: 5, node: "worker.2", paused: false, queue: :alpha)
    notify(pid, gossip(), count: 3, limit: 5, node: "worker.1", paused: false, queue: :gamma)
    notify(pid, gossip(), count: 1, limit: 5, node: "worker.2", paused: false, queue: :gamma)
    notify(pid, gossip(), count: 1, limit: 5, node: "worker.1", paused: false, queue: :delta)
    notify(pid, gossip(), count: 1, limit: 5, node: "worker.2", paused: false, queue: :delta)

    with_backoff(fn ->
      assert for_nodes() == %{"worker.1" => 6, "worker.2" => 3}
    end)

    notify(pid, gossip(), count: 1, limit: 5, node: "worker.1", paused: false, queue: :alpha)
    notify(pid, gossip(), count: 0, limit: 5, node: "worker.2", paused: false, queue: :alpha)
    notify(pid, gossip(), count: 4, limit: 5, node: "worker.1", paused: false, queue: :gamma)
    notify(pid, gossip(), count: 2, limit: 5, node: "worker.2", paused: false, queue: :gamma)
    notify(pid, gossip(), count: 0, limit: 5, node: "worker.1", paused: false, queue: :delta)
    notify(pid, gossip(), count: 2, limit: 5, node: "worker.2", paused: false, queue: :delta)

    with_backoff(fn ->
      assert for_nodes() == %{"worker.1" => 5, "worker.2" => 4}
    end)

    stop_supervised(Stats)
  end

  test "counts are refreshed from the database to prevent drift" do
    {:ok, pid} = start_supervised({Stats, @opts})

    insert_job!(queue: :gamma, state: "available")
    insert_job!(queue: :delta, state: "available")

    send(pid, :refresh)

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => {0, 0, 2},
               "delta" => {0, 1, 2},
               "gamma" => {0, 1, 3}
             }
    end)
  end

  test "signal notifications modify the tracked queue limits" do
    {:ok, pid} = start_supervised({Stats, @opts})

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => {0, 0, 2},
               "delta" => {0, 0, 2},
               "gamma" => {0, 0, 3}
             }
    end)

    notify(pid, signal(), action: :scale, queue: :gamma, scale: 7)
    notify(pid, signal(), action: :scale, queue: :delta, scale: 4)

    with_backoff(fn ->
      assert for_queues() == %{
               "alpha" => {0, 0, 2},
               "delta" => {0, 0, 4},
               "gamma" => {0, 0, 7}
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

  defp notify(pid, event, payload) do
    encoded = Jason.encode!(Map.new(payload))

    send(pid, {:notification, nil, nil, event, encoded})
  end
end
