defmodule Oban.Web.Plugins.Stats do
  @moduledoc false

  use GenServer

  alias Oban.Notifier
  alias Oban.Web.Query

  @states ~w(executing available scheduled retryable cancelled discarded completed)

  @empty_states for state <- @states, into: %{}, do: {state, 0}

  defmodule State do
    @moduledoc false

    defstruct [
      :conf,
      :name,
      :table,
      :timer,
      active: MapSet.new(),
      interval: :timer.seconds(1),
      slow_query_limit: 10_000,
      slow_query_ratio: 60,
      ticks: 0,
      ttl: :timer.seconds(15)
    ]
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @spec all_gossip(GenServer.name()) :: list(map())
  def all_gossip(oban_name) do
    case fetch_table(oban_name) do
      {:ok, table} -> :ets.select(table, [{{{:gossip, :_, :_, :_}, :_, :"$1"}, [], [:"$1"]}])
      {:error, _} -> []
    end
  end

  @spec all_counts(GenServer.name()) :: list(map())
  def all_counts(oban_name) do
    case fetch_table(oban_name) do
      {:ok, table} -> :ets.select(table, [{{{:count, :_}, :"$1"}, [], [:"$1"]}])
      {:error, _} -> []
    end
  end

  @spec activate(GenServer.name(), timeout()) :: :ok
  def activate(oban_name, timeout \\ 15_000) do
    oban_name
    |> Oban.Registry.via({:plugin, __MODULE__})
    |> GenServer.call(:activate, timeout)
  end

  @spec fetch_table(GenServer.name()) :: {:ok, :ets.tab()} | {:error, term()}
  def fetch_table(oban_name) do
    case Registry.meta(Oban.Registry, {oban_name, {:plugin, __MODULE__}}) do
      {:ok, table} when is_reference(table) ->
        if :ets.info(table) != :undefined do
          {:ok, table}
        else
          {:error, :bad_table_reference}
        end

      result ->
        {:error, result}
    end
  rescue
    ArgumentError -> {:error, :bad_table_reference}
  end

  # Callbacks

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    table = :ets.new(:stats, [:public, read_concurrency: true])
    state = struct!(State, Keyword.put(opts, :table, table))

    Registry.put_meta(
      Oban.Registry,
      {state.conf.name, {:plugin, __MODULE__}},
      table
    )

    :ok = Notifier.listen(state.conf.name, [:gossip])

    {:ok, state}
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

  def handle_info({:notification, :gossip, %{"node" => _} = payload}, %State{} = state) do
    %{"node" => node, "name" => name, "queue" => queue} = payload

    timestamp = System.system_time(:millisecond)

    :ets.insert(state.table, {{:gossip, node, name, queue}, timestamp, payload})

    {:noreply, state}
  end

  def handle_info(:refresh, %State{} = state) do
    {:noreply, refresh(state)}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  ## Refresh Helpers

  defp maybe_start_refresh(%State{active: active} = state) do
    if Enum.empty?(active) do
      refresh(state)
    else
      state
    end
  end

  defp maybe_cancel_refresh(%State{active: active} = state) do
    if Enum.empty?(active) do
      cancel_refresh(state)
    else
      state
    end
  end

  defp refresh(state) do
    expire_gossip(state)
    update_counts(state)

    timer = Process.send_after(self(), :refresh, state.interval)

    %{state | ticks: state.ticks + 1, timer: timer}
  end

  defp cancel_refresh(%State{timer: timer} = state) do
    if is_reference(timer), do: Process.cancel_timer(timer)

    %{state | ticks: 0, timer: nil}
  end

  defp expire_gossip(%State{table: table, ttl: ttl}) do
    expires = System.system_time(:millisecond) - ttl
    pattern = [{{{:gossip, :_, :_, :_}, :"$1", :_}, [{:<, :"$1", expires}], [true]}]

    :ets.select_delete(table, pattern)
  end

  defp update_counts(%State{conf: conf, table: table} = state) do
    {slow_states, fast_states} = partition_states_by_speed(state)

    fast_counts = Query.queue_state_counts(conf, fast_states)

    slow_counts =
      if Enum.empty?(slow_states) or perform_slow_query?(state) do
        counts = Query.queue_state_counts(conf, slow_states)

        # When we're performing fast and slow counts we know it's safe to purge
        :ets.select_delete(table, [{{{:count, :_}, :_}, [], [true]}])

        counts
      else
        []
      end

    both_counts = fast_counts ++ slow_counts

    prev_counts =
      table
      |> :ets.select([{{{:count, :_}, :"$1"}, [], [:"$1"]}])
      |> Map.new(fn %{"name" => name} = payload -> {name, payload} end)

    for {queue, payload} <- Enum.reduce(both_counts, prev_counts, &merge_queue_counts/2) do
      :ets.insert(table, {{:count, queue}, payload})
    end
  end

  defp partition_states_by_speed(%State{slow_query_limit: limit, table: table}) do
    {slow_states, fast_states} =
      table
      |> :ets.select([{{{:count, :_}, :"$1"}, [], [:"$1"]}])
      |> Enum.reduce(@empty_states, &merge_state_counts/2)
      |> Enum.split_with(fn {_state, count} -> count > limit end)

    {Enum.map(slow_states, &elem(&1, 0)), Enum.map(fast_states, &elem(&1, 0))}
  end

  defp perform_slow_query?(%State{slow_query_ratio: ratio, ticks: ticks}) do
    Integer.mod(ticks, ratio) == 0
  end

  defp merge_state_counts(counts, states) do
    for {key, val} <- counts, key != "name", reduce: states do
      acc -> Map.update!(acc, key, &(&1 + val))
    end
  end

  defp merge_queue_counts({queue, state, count}, acc) do
    acc
    |> Map.put_new_lazy(queue, fn -> Map.put(@empty_states, "name", queue) end)
    |> put_in([queue, state], count)
  end
end
