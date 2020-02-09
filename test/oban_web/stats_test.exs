defmodule ObanWeb.StatsTest do
  use ObanWeb.DataCase

  alias Oban.{Beat, Job}
  alias ObanWeb.{Config, Stats}

  @name __MODULE__
  @conf Config.new(repo: ObanWeb.Repo, stats_interval: 10)
  @opts [name: @name, conf: @conf, table: @name]

  setup do
    :ets.new(@name, [:public, :named_table, read_concurrency: true])

    :ok
  end

  test "node and queue stats aren't tracked without an active connection" do
    insert_job!(queue: :alpha, state: "available")
    insert_beat!(node: "web.1", queue: "alpha", limit: 4)

    start_supervised!({Stats, @opts})

    assert for_nodes() == %{}
    assert for_queues() == %{}

    assert for_states() == %{
             "executing" => %{count: 0},
             "available" => %{count: 0},
             "scheduled" => %{count: 0},
             "retryable" => %{count: 0},
             "discarded" => %{count: 0},
             "completed" => %{count: 0}
           }

    stop_supervised(Stats)
  end

  test "updating node and queue stats after activation" do
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

    :ok = Stats.activate(@name)

    assert for_nodes() == %{
             "web.1" => %{count: 0, limit: 9},
             "web.2" => %{count: 0, limit: 18}
           }

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

    stop_supervised(Stats)
  end

  test "refreshing stops when all activated nodes disconnect" do
    start_supervised!({Stats, @opts})

    insert_job!(queue: :alpha, state: "available")
    insert_beat!(node: "web.1", queue: "alpha", limit: 4)

    fn -> :ok = Stats.activate(@name) end
    |> Task.async()
    |> Task.await()

    insert_job!(queue: :alpha, state: "available")
    insert_beat!(node: "web.2", queue: "alpha", limit: 4)

    # The refresh rate is 10ms, after 20ms the values still should not have refreshed
    Process.sleep(20)

    assert for_nodes() == %{"web.1" => %{count: 0, limit: 4}}
    assert for_queues() == %{"alpha" => %{avail: 1, execu: 0, limit: 4}}

    stop_supervised(Stats)
  end

  defp for_nodes, do: @name |> Stats.for_nodes() |> Map.new()
  defp for_queues, do: @name |> Stats.for_queues() |> Map.new()
  defp for_states, do: @name |> Stats.for_states() |> Map.new()

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

  defp seconds_ago(seconds) do
    DateTime.add(DateTime.utc_now(), -seconds)
  end
end
