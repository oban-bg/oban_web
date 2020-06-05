defmodule Oban.Web.Stats do
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

  alias Oban.Web.Query

  @ordered_states ~w(executing available scheduled retryable discarded completed)

  defmodule State do
    @moduledoc false

    defstruct [
      :conf,
      :table,
      :refresh_ref,
      active: MapSet.new()
    ]
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, Map.new(opts), name: name)
  end

  @spec for_nodes(module()) :: list({binary(), map()})
  def for_nodes(table) do
    table
    |> :ets.select([{{{:node, :"$1", :_}, :"$2", :"$3", :_}, [], [:"$$"]}])
    |> Enum.sort_by(&hd/1)
    |> Enum.reduce(%{}, fn [node, count, limit], acc ->
      Map.update(acc, node, %{count: count, limit: limit}, fn map ->
        %{map | count: map.count + count, limit: map.limit + limit}
      end)
    end)
  end

  @spec for_queues(module()) :: list({binary(), map()})
  def for_queues(table) do
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

    local_limits =
      table
      |> :ets.select([{{{:node, :_, :"$1"}, :_, :"$2", :_}, [], [:"$$"]}])
      |> Map.new(fn [queue, limit] -> {queue, limit} end)

    pause_states =
      table
      |> :ets.select([{{{:node, :_, :"$1"}, :_, :_, :"$2"}, [], [:"$$"]}])
      |> Enum.reduce(%{}, fn [queue, paused], acc ->
        Map.update(acc, queue, paused, &(&1 or paused))
      end)

    [avail_counts, execu_counts, limit_counts]
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn queue ->
      {queue,
       %{
         avail: Map.get(avail_counts, queue, 0),
         execu: Map.get(execu_counts, queue, 0),
         limit: Map.get(limit_counts, queue, 0),
         local: Map.get(local_limits, queue, 0),
         pause: Map.get(pause_states, queue, true)
       }}
    end)
  end

  @spec for_states(module()) :: list({binary(), map()})
  def for_states(table) do
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

  @spec activate(module()) :: :ok
  def activate(name \\ __MODULE__) do
    GenServer.call(name, :activate)
  end

  @impl GenServer
  def init(%{conf: conf, table: table}) do
    Process.flag(:trap_exit, true)

    {:ok, struct!(State, conf: conf, table: table)}
  end

  @impl GenServer
  def terminate(_reason, %State{} = state) do
    cancel_refresh(state)

    :ok
  end

  @impl GenServer
  def handle_call(:activate, {pid, _ref}, %State{active: active} = state) do
    Process.monitor(pid)

    state =
      state
      |> maybe_start_refresh()
      |> Map.replace!(:active, MapSet.put(active, pid))

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %State{active: active} = state) do
    state =
      state
      |> Map.replace!(:active, MapSet.delete(active, pid))
      |> maybe_cancel_refresh()

    {:noreply, state}
  end

  def handle_info(:refresh, %State{} = state) do
    {:noreply, refresh(state)}
  end

  # Helpers

  defp maybe_start_refresh(%State{active: active} = state) do
    if Enum.empty?(active), do: refresh(state), else: state
  end

  defp maybe_cancel_refresh(%State{active: active} = state) do
    if Enum.empty?(active), do: cancel_refresh(state), else: state
  end

  defp refresh(%State{conf: conf} = state) do
    node_keys = update_node_counts(state)
    queue_keys = update_queue_counts(state)

    clear_unused_keys(node_keys ++ queue_keys, state)

    ref = Process.send_after(self(), :refresh, conf.stats_interval)

    %{state | refresh_ref: ref}
  end

  defp cancel_refresh(%State{refresh_ref: refresh_ref} = state) do
    unless is_nil(refresh_ref), do: Process.cancel_timer(refresh_ref)

    %{state | refresh_ref: nil}
  end

  defp clear_unused_keys(prior_keys, %State{table: table}) do
    fn object, acc -> [elem(object, 0) | acc] end
    |> :ets.foldl([], table)
    |> Kernel.--(prior_keys)
    |> Enum.each(&:ets.delete(table, &1))
  end

  defp update_node_counts(%State{conf: conf, table: table}) do
    for {node, queue, count, limit, paused} <- Query.node_counts(conf) do
      key = {:node, node, queue}

      :ets.insert(table, {key, count, limit, paused})

      key
    end
  end

  defp update_queue_counts(%State{conf: conf, table: table}) do
    for {queue, state, count} <- Query.queue_counts(conf) do
      key = {:queue, queue, state}

      :ets.insert(table, {key, count})

      key
    end
  end
end
