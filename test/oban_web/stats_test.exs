defmodule ObanWeb.StatsTest do
  use ObanWeb.DataCase

  alias Oban.Job
  alias ObanWeb.Stats

  @name __MODULE__
  @opts [name: @name, queues: [alpha: 1, gamma: 1, delta: 1], repo: ObanWeb.Repo]

  test "initializing with current state and queue counts" do
    insert_job!(queue: :alpha, state: "available")
    insert_job!(queue: :alpha, state: "executing")
    insert_job!(queue: :gamma, state: "available")
    insert_job!(queue: :gamma, state: "scheduled")
    insert_job!(queue: :gamma, state: "completed")

    start_supervised!({Stats, @opts})

    Process.sleep(20)

    assert Stats.for_queues(@name) == %{"delta" => 0, "alpha" => 1, "gamma" => 1}

    assert Stats.for_states(@name) == %{
             "executing" => 1,
             "available" => 2,
             "scheduled" => 1,
             "retryable" => 0,
             "discarded" => 0,
             "completed" => 1
           }

    stop_supervised(Stats)
  end

  test "insert notifications modify the cached values" do
    {:ok, pid} = start_supervised({Stats, @opts})

    notify(pid, :insert, queue: :alpha, state: "available")
    notify(pid, :insert, queue: :gamma, state: "available")
    notify(pid, :insert, queue: :delta, state: "scheduled")

    Process.sleep(20)

    assert Stats.for_queues(@name) == %{"alpha" => 1, "gamma" => 1, "delta" => 0}

    assert Stats.for_states(@name) == %{
             "executing" => 0,
             "available" => 2,
             "scheduled" => 1,
             "retryable" => 0,
             "discarded" => 0,
             "completed" => 0
           }

    stop_supervised(Stats)
  end

  test "update notifications modify the cached values" do
    insert_job!(queue: :alpha, state: "available")
    insert_job!(queue: :gamma, state: "available")
    insert_job!(queue: :gamma, state: "scheduled")
    insert_job!(queue: :delta, state: "executing")

    {:ok, pid} = start_supervised({Stats, @opts})

    notify(pid, :update, queue: :alpha, old_state: "available", new_state: "executing")
    notify(pid, :update, queue: :gamma, old_state: "scheduled", new_state: "available")
    notify(pid, :update, queue: :gamma, old_state: "available", new_state: "executing")
    notify(pid, :update, queue: :delta, old_state: "executing", new_state: "completed")

    Process.sleep(20)

    assert Stats.for_queues(@name) == %{"alpha" => 0, "gamma" => 1, "delta" => 0}

    assert Stats.for_states(@name) == %{
             "executing" => 2,
             "available" => 1,
             "scheduled" => 0,
             "retryable" => 0,
             "discarded" => 0,
             "completed" => 1
           }

    stop_supervised(Stats)
  end

  test "counts are refreshed from the database to prevent drift" do
    {:ok, pid} = start_supervised({Stats, @opts})

    insert_job!(queue: :gamma, state: "available")
    insert_job!(queue: :delta, state: "available")

    send(pid, :refresh)

    Process.sleep(20)

    assert Stats.for_queues(@name) == %{"alpha" => 0, "gamma" => 1, "delta" => 1}
  end

  # tracks execs/avail/limit for queues
  # track nodes through gossip

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

    full_event =
      case event do
        :insert -> "oban_insert"
        :update -> "oban_update"
      end

    send(pid, {:notification, nil, nil, full_event, encoded})
  end
end
