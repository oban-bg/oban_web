defmodule Oban.Web.Plugins.Stats do
  @moduledoc """
  Cache for tracking queue, state and node counts for display.
  """

  use GenServer

  alias Oban.Notifier
  alias Oban.Web.Query

  @ordered_states ~w(executing available scheduled retryable cancelled discarded completed)

  defmodule State do
    @moduledoc false

    defstruct [
      :conf,
      :name,
      :table,
      :timer,
      active: MapSet.new(),
      interval: :timer.seconds(1),
      ttl: :timer.seconds(15)
    ]
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @spec for_nodes(GenServer.name()) :: list({binary(), map()})
  def for_nodes(oban_name \\ Oban) do
    oban_name
    |> table()
    |> :ets.select([{{{:node, :_, :_, :_}, :_, :"$1"}, [], [:"$1"]}])
    |> Enum.reduce(%{}, fn payload, acc ->
      limit = payload_limit(payload)
      count = payload |> Map.get("running", []) |> length()

      nname =
        [payload["name"], payload["node"]]
        |> Enum.join("/")
        |> String.trim_leading("Elixir.")
        |> String.downcase()

      Map.update(acc, nname, %{count: count, limit: limit}, fn map ->
        %{map | count: map.count + count, limit: map.limit + limit}
      end)
    end)
  end

  @spec for_queues(GenServer.name()) :: list({binary(), map()})
  def for_queues(oban_name \\ Oban) do
    table = table(oban_name)

    counter = fn type ->
      table
      |> :ets.select([{{{:queue, :"$1", type}, :"$2"}, [], [:"$$"]}])
      |> Map.new(fn [queue, count] -> {queue, count} end)
    end

    avail_counts = counter.("available")
    execu_counts = counter.("executing")

    limit_counts =
      table
      |> :ets.select([{{{:node, :_, :_, :"$1"}, :_, :"$2"}, [], [:"$$"]}])
      |> Enum.reduce(%{}, fn [queue, payload], acc ->
        limit = payload_limit(payload)

        Map.update(acc, queue, limit, &(&1 + limit))
      end)

    local_limits =
      table
      |> :ets.select([{{{:node, :_, :_, :"$1"}, :_, :"$2"}, [], [:"$$"]}])
      |> Map.new(fn [queue, payload] -> {queue, payload_limit(payload)} end)

    pause_states =
      table
      |> :ets.select([{{{:node, :_, :_, :"$1"}, :_, :"$2"}, [], [:"$$"]}])
      |> Enum.reduce(%{}, fn [queue, %{"paused" => paused}], acc ->
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

  @spec for_states(GenServer.name()) :: list({binary(), map()})
  def for_states(oban_name \\ Oban) do
    table = table(oban_name)

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

  @spec activate(GenServer.name(), timeout()) :: :ok
  def activate(oban_name, timeout \\ 15_000) do
    oban_name
    |> Oban.Registry.via({:plugin, __MODULE__})
    |> GenServer.call(:activate, timeout)
  end

  @spec table(GenServer.name()) :: :ets.tab()
  def table(oban_name) do
    {:ok, table} = Registry.meta(Oban.Registry, {oban_name, {:plugin, __MODULE__}})

    table
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

    :ets.insert(state.table, {{:node, node, name, queue}, timestamp, payload})

    {:noreply, state}
  end

  def handle_info(:refresh, %State{} = state) do
    {:noreply, refresh(state)}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  # Helpers

  defp maybe_start_refresh(%State{active: active} = state) do
    if Enum.empty?(active) do
      :ok = Notifier.listen(state.conf.name, [:gossip])

      refresh(state)
    else
      state
    end
  end

  defp maybe_cancel_refresh(%State{active: active} = state) do
    if Enum.empty?(active) do
      :ok = Notifier.unlisten(state.conf.name, [:gossip])

      cancel_refresh(state)
    else
      state
    end
  end

  defp refresh(state) do
    expire_older_keys(state)
    update_queue_counts(state)

    %{state | timer: Process.send_after(self(), :refresh, state.interval)}
  end

  defp cancel_refresh(%State{timer: timer} = state) do
    if is_reference(timer), do: Process.cancel_timer(timer)

    %{state | timer: nil}
  end

  defp expire_older_keys(%State{table: table, ttl: ttl}) do
    expires = System.system_time(:millisecond) - ttl
    pattern = [{{{:node, :_, :_, :_}, :"$1", :_}, [{:<, :"$1", expires}], [true]}]

    :ets.select_delete(table, pattern)
  end

  defp update_queue_counts(%State{conf: conf, table: table}) do
    for {queue, state, count} <- Query.queue_counts(conf) do
      :ets.insert(table, {{:queue, queue, state}, count})
    end
  end

  defp payload_limit(%{"global_limit" => limit}), do: limit
  defp payload_limit(%{"local_limit" => limit}), do: limit
  defp payload_limit(%{"limit" => limit}), do: limit
  defp payload_limit(_payload), do: 0
end
