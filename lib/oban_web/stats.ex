defmodule ObanWeb.Stats do
  @moduledoc """
  Cache for tracking queue, state and node counts for display.

  Count operations are particularly expensive in Postgres, especially if there are a lot of jobs.
  The `Stats` module uses ETS and PubSub to track changes efficiently, avoiding repeated slow
  database operations.

  There are three categories of stats:

  1. `:node` — pulled from `oban_beats` and and various pubsub messages, contains details about
     each queue running on a particular node.
  2. `:queue` — pulled from `oban_jobs` and insert pubsub, contains the available and executing
     counts for each queue _across_ all nodes.
  3. `:state` — pulled from `oban_jobs` and updated by insert pubsub messages.

  Stats are stored with the following structure:

  - `{{:node, node, queue}, count, limit, paused}`
  - `{{:queue, queue, state}, count}`
  """

  use GenServer

  import Oban.Notifier, only: [gossip: 0, insert: 0, signal: 0]

  alias Oban.Notifier
  alias ObanWeb.Query

  @ordered_states ~w(executing available scheduled retryable discarded completed)

  defmodule State do
    @moduledoc false

    defstruct [
      :repo,
      :table,
      :refresh_ref,
      refresh_interval: :timer.seconds(1)
    ]
  end

  def start_link(opts) when is_list(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, Map.new(opts), name: opts[:name])
  end

  def for_nodes(table \\ __MODULE__) do
    table
    |> :ets.select([{{{:node, :"$1", :_}, :"$2", :"$3", :_}, [], [:"$$"]}])
    |> Enum.sort_by(&hd/1)
    |> Enum.reduce(%{}, fn [node, count, limit], acc ->
      Map.update(acc, node, %{count: count, limit: limit}, fn map ->
        %{map | count: map.count + count, limit: map.limit + limit}
      end)
    end)
  end

  def for_queues(table \\ __MODULE__) do
    counter = fn type ->
      table
      |> :ets.select([{{{:queue, :"$1", type}, :"$2"}, [], [:"$$"]}])
      |> Map.new(fn [queue, count] -> {queue, count} end)
    end

    avail_counts = counter.("available")
    execu_counts = counter.("executing")

    limit_counts =
      table
      |> :ets.select([{{{:node, :_, :"$1"}, :_, :"$2", :_}, [], [:"$$"]}])
      |> Enum.reduce(%{}, fn [queue, limit], acc ->
        Map.update(acc, queue, limit, &(&1 + limit))
      end)

    [avail_counts, execu_counts, limit_counts]
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn queue ->
      counts = %{
        avail: Map.get(avail_counts, queue, 0),
        execu: Map.get(execu_counts, queue, 0),
        limit: Map.get(limit_counts, queue, 0)
      }

      {queue, counts}
    end)
  end

  def for_states(table \\ __MODULE__) do
    for state <- @ordered_states do
      count =
        case :ets.select(table, [{{{:queue, :_, state}, :"$1"}, [], [:"$$"]}]) do
          [_ | _] = results ->
            results
            |> Enum.map(&hd/1)
            |> Enum.sum()

          _ ->
            0
        end

      {state, %{count: count}}
    end
  end

  @impl GenServer
  def init(%{conf: conf, name: name}) do
    Process.flag(:trap_exit, true)

    table = :ets.new(name, [:protected, :named_table, read_concurrency: true])

    {:ok, struct!(State, repo: conf.repo, table: table), {:continue, :start}}
  end

  @impl GenServer
  def terminate(_reason, %State{refresh_ref: refresh_ref}) do
    unless is_nil(refresh_ref), do: Process.cancel_timer(refresh_ref)

    :ok
  end

  @impl GenServer
  def handle_continue(:start, state) do
    :ok = Notifier.listen(Oban.Notifier)

    handle_info(:refresh, state)
  end

  @impl GenServer
  def handle_info(:refresh, %State{} = state) do
    node_keys = fetch_node_counts(state)
    queue_keys = fetch_queue_counts(state)

    clear_unused_keys(node_keys ++ queue_keys, state)

    ref = Process.send_after(self(), :refresh, state.refresh_interval)

    {:noreply, %{state | refresh_ref: ref}}
  end

  def handle_info({:notification, gossip(), payload}, %State{table: table} = state) do
    %{"node" => node, "queue" => queue, "count" => count} = payload
    %{"limit" => limit, "paused" => paused} = payload

    :ets.insert(table, {{:node, node, queue}, count, limit, paused})

    {:noreply, state}
  end

  def handle_info({:notification, insert(), payload}, %State{table: table} = state) do
    %{"state" => job_state, "queue" => queue} = payload

    :ets.update_counter(table, {:queue, queue, job_state}, 1, {1, 0})

    {:noreply, state}
  end

  def handle_info({:notification, signal(), payload}, %State{table: table} = state) do
    with %{"action" => "scale", "queue" => queue, "scale" => scale} <- payload do
      pattern = {{{:node, :_, queue}, :_, :_, :_}, [], [:"$_"]}

      for match <- :ets.select(table, [pattern]) do
        :ets.insert(table, put_elem(match, 2, scale))
      end
    end

    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  # Helpers

  defp clear_unused_keys(prior_keys, %State{table: table}) do
    fn object, acc -> [elem(object, 0) | acc] end
    |> :ets.foldl([], table)
    |> Kernel.--(prior_keys)
    |> Enum.each(&:ets.delete(table, &1))
  end

  defp fetch_node_counts(%State{repo: repo, table: table}) do
    for {node, queue, count, limit, paused} <- Query.node_counts(repo) do
      key = {:node, node, queue}

      :ets.insert(table, {key, count, limit, paused})

      key
    end
  end

  defp fetch_queue_counts(%State{repo: repo, table: table}) do
    for {queue, state, count} <- Query.queue_counts(repo) do
      key = {:queue, queue, state}

      :ets.insert(table, {key, count})

      key
    end
  end
end
