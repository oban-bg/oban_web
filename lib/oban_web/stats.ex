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

  @ordered_states ~w(executing available scheduled retryable discarded completed)

  defmodule State do
    @moduledoc false

    defstruct [
      :repo,
      :table,
      :latest_update,
      :refresh_ref,
      refresh_interval: :timer.seconds(60),
      update_threshold: :timer.seconds(3)
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

    avail_counts = counter.(:avail)
    execu_counts = counter.(:execu)

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
      case :ets.lookup(table, {:state, state}) do
        [{_, count}] -> {state, %{count: count}}
        _ -> {state, %{count: 0}}
      end
    end
  end

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)

    table = :ets.new(opts[:name], [:protected, :named_table, read_concurrency: true])

    opts =
      opts
      |> Map.take([:repo, :update_threshold])
      |> Map.put(:table, table)

    {:ok, struct!(State, opts), {:continue, :start}}
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
  def handle_info(:refresh, %State{repo: repo} = state) do
    clear_table(state)

    repo.checkout(fn ->
      fetch_node_counts(state)
      fetch_queue_counts(state)
      fetch_state_counts(state)
    end)

    ref = Process.send_after(self(), :refresh, state.refresh_interval)

    {:noreply, %{state | latest_update: unix_now(), refresh_ref: ref}}
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

  # Update notifications are batched, which makes the counting innacurate. For example, if two
  # jobs are moved from `scheduled` to `available` in a single transaction only one update event
  # is emitted. Instead of relying on individual update events for state changes we use them to
  # trigger a refresh with a small debounce.
  def handle_info({:notification, update(), _payload}, state) do
    %State{repo: repo, latest_update: latest, update_threshold: threshold} = state

    if unix_now() > latest + threshold do
      repo.checkout(fn ->
        fetch_queue_counts(state)
        fetch_state_counts(state)
      end)

      # Intentionally delay the latest_update until _after_ the refresh has completed.
      {:noreply, %{state | latest_update: unix_now()}}
    else
      {:noreply, state}
    end
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

  defp unix_now do
    DateTime.to_unix(DateTime.utc_now(), :millisecond)
  end
end
