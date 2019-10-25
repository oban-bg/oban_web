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
  - `{{:queue, queue, :avail}, count}`
  - `{{:queue, queue, :execu}, count}`
  - `{{:state, state}, count}`
  """

  use GenServer

  import Oban.Notifier, only: [gossip: 0, insert: 0, signal: 0, update: 0]

  alias Oban.Notifier
  alias ObanWeb.Query

  @type option :: {:name, atom()} | {:queues, Keyword.t()} | {:repo, module()}

  @ordered_states ~w(executing available scheduled retryable discarded completed)

  defmodule State do
    @moduledoc false

    defstruct [:queues, :repo, :table, refresh_interval: :timer.seconds(60)]
  end

  def start_link(opts) when is_list(opts) do
    opts =
      opts
      |> Keyword.put_new(:name, __MODULE__)
      |> Keyword.put(:queues, Keyword.get(opts, :queues) || [])

    GenServer.start_link(__MODULE__, opts, name: opts[:name])
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

    avail_counts = counter.(:avail)
    execu_counts = counter.(:execu)

    limit_counts =
      table
      |> :ets.select([{{{:node, :_, :"$1"}, :_, :"$2", :_}, [], [:"$$"]}])
      |> Map.new(fn [queue, count] -> {queue, count} end)

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
      case :ets.lookup(table, {:state, state}) do
        [{_, count}] -> {state, %{count: count}}
        _ -> {state, %{count: 0}}
      end
    end
  end

  @impl GenServer
  def init(opts) do
    table = :ets.new(opts[:name], [:protected, :named_table, read_concurrency: true])
    state = %State{repo: opts[:repo], table: table}

    {:ok, state, {:continue, :start}}
  end

  @impl GenServer
  def handle_continue(:start, state) do
    :ok = Notifier.listen(Oban.Notifier)

    handle_info(:refresh, state)
  end

  @impl GenServer
  def handle_info(:refresh, %State{repo: repo} = state) do
    clear_table(state)

    repo.checkout(fn ->
      fetch_node_counts(state)
      fetch_queue_counts(state)
      fetch_state_counts(state)
    end)

    Process.send_after(self(), :refresh, state.refresh_interval)

    {:noreply, state}
  end

  def handle_info({:notification, gossip(), payload}, %State{table: table} = state) do
    %{"node" => node, "queue" => queue, "count" => count} = payload
    %{"limit" => limit, "paused" => paused} = payload

    :ets.insert(table, {{:node, node, queue}, count, limit, paused})

    {:noreply, state}
  end

  def handle_info({:notification, insert(), payload}, %State{table: table} = state) do
    %{"state" => job_state, "queue" => queue} = payload

    :ets.update_counter(table, {:state, job_state}, 1, {1, 0})

    if job_state == "available" do
      :ets.update_counter(table, {:queue, queue, :avail}, 1, {1, 0})
    end

    {:noreply, state}
  end

  def handle_info({:notification, update(), payload}, %State{table: table} = state) do
    %{"queue" => queue, "new_state" => new, "old_state" => old} = payload

    :ets.update_counter(table, {:state, old}, -1, {1, 1})
    :ets.update_counter(table, {:state, new}, 1, {1, 0})

    avail_incr = state_to_incr(new, old, "available")
    execu_incr = state_to_incr(new, old, "executing")

    :ets.update_counter(table, {:queue, queue, :avail}, avail_incr, {1, 0})
    :ets.update_counter(table, {:queue, queue, :execu}, execu_incr, {1, 0})

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

  defp clear_table(%State{table: table}) do
    :ets.delete_all_objects(table)
  end

  defp fetch_node_counts(%State{repo: repo, table: table}) do
    for {node, queue, count, limit, paused} <- Query.node_counts(repo) do
      :ets.insert(table, {{:node, node, queue}, count, limit, paused})
    end
  end

  defp fetch_queue_counts(%State{repo: repo, table: table}) do
    for {queue, state, count} <- Query.queue_counts(repo) do
      :ets.insert(table, {{:queue, queue, short_state(state)}, count})
    end
  end

  defp fetch_state_counts(%State{repo: repo, table: table}) do
    for {state, count} <- Query.state_counts(repo) do
      :ets.insert(table, {{:state, state}, count})
    end
  end

  defp short_state("available"), do: :avail
  defp short_state("executing"), do: :execu

  defp state_to_incr(new, _ol, new), do: 1
  defp state_to_incr(_ne, old, old), do: -1
  defp state_to_incr(_ne, _ol, _an), do: 0
end
