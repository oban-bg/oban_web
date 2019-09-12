defmodule ObanWeb.Stats do
  @moduledoc """
  Cache for tracking queue, state and node counts for display.

  Count operations are particularly expensive in Postgres, especially if there are a lot of jobs.
  The `Stats` module uses ETS and PubSub to track changes efficiently, avoiding repeated slow
  database operations.
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

  @spec start_link([option()]) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    opts =
      opts
      |> Keyword.put_new(:name, __MODULE__)
      |> Keyword.put(:queues, Keyword.get(opts, :queues) || [])

    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @spec for_nodes(module()) :: %{optional(binary()) => non_neg_integer()}
  def for_nodes(name \\ __MODULE__) do
    name
    |> :ets.select([{{{:node, :"$1", :_}, :"$2"}, [], [:"$$"]}])
    |> Enum.sort_by(&hd/1)
    |> Enum.reduce(%{}, fn [nname, count], acc ->
      Map.update(acc, nname, count, &(&1 + count))
    end)
  end

  @spec for_queues(module()) :: %{optional(binary()) => {integer(), integer(), integer()}}
  def for_queues(name \\ __MODULE__) do
    counter = fn type ->
      name
      |> :ets.select([{{{:queue, :"$1", type}, :"$3"}, [], [:"$$"]}])
      |> Map.new(fn [queue, count] -> {queue, count} end)
    end

    avail_counts = counter.(:avail)
    execu_counts = counter.(:execu)
    limit_counts = counter.(:limit)

    for {queue, _avail} <- limit_counts do
      counts = {
        Map.get(execu_counts, queue, 0),
        Map.get(avail_counts, queue, 0),
        Map.get(limit_counts, queue, 0)
      }

      {queue, counts}
    end
  end

  @spec for_states(module()) :: %{optional(binary()) => non_neg_integer()}
  def for_states(name \\ __MODULE__) do
    for state <- @ordered_states do
      case :ets.lookup(name, {:state, state}) do
        [{_, count}] -> {state, count}
        _ -> {state, 0}
      end
    end
  end

  @impl GenServer
  def init(opts) do
    table = :ets.new(opts[:name], [:protected, :named_table, read_concurrency: true])
    state = %State{queues: opts[:queues], repo: opts[:repo], table: table}

    {:ok, state, {:continue, :start}}
  end

  @impl GenServer
  def handle_continue(:start, state) do
    fetch_queue_limits(state)
    fetch_queue_counts(state)
    fetch_state_counts(state)
    fetch_node_counts(state)

    Process.send_after(self(), :refresh, state.refresh_interval)

    # NOTE: This only works for a default cofiguration using the public schema
    :ok = Notifier.listen(Oban.Notifier, "public", :gossip)
    :ok = Notifier.listen(Oban.Notifier, "public", :insert)
    :ok = Notifier.listen(Oban.Notifier, "public", :update)
    :ok = Notifier.listen(Oban.Notifier, "public", :signal)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:refresh, state) do
    fetch_state_counts(state)
    fetch_queue_counts(state)
    fetch_node_counts(state)

    Process.send_after(self(), :refresh, state.refresh_interval)

    {:noreply, state}
  end

  def handle_info({:notification, _, _, prefixed_channel, payload}, state) do
    [_prefix, channel] = String.split(prefixed_channel, ".")

    handle_notification(channel, payload, state)
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  def handle_notification(gossip(), payload, %State{table: table} = state) do
    %{"node" => node, "queue" => queue, "count" => count} = Jason.decode!(payload)

    :ets.insert(table, {{:node, node, queue}, count})

    {:noreply, state}
  end

  def handle_notification(insert(), payload, %State{table: table} = state) do
    %{"state" => job_state, "queue" => job_queue} = Jason.decode!(payload)

    :ets.update_counter(table, {:state, job_state}, 1, {1, 0})

    if job_state == "available" do
      :ets.update_counter(table, {:queue, job_queue, :avail}, 1, {1, 0})
    end

    {:noreply, state}
  end

  def handle_notification(update(), payload, %State{table: table} = state) do
    %{"queue" => queue, "new_state" => new, "old_state" => old} = Jason.decode!(payload)

    :ets.update_counter(table, {:state, old}, -1, {1, 1})
    :ets.update_counter(table, {:state, new}, 1, {1, 0})

    avail_incr = state_to_incr(new, old, "available")
    execu_incr = state_to_incr(new, old, "executing")

    :ets.update_counter(table, {:queue, queue, :avail}, avail_incr, {1, 0})
    :ets.update_counter(table, {:queue, queue, :execu}, execu_incr, {1, 0})

    {:noreply, state}
  end

  def handle_notification(signal(), payload, %State{table: table} = state) do
    with %{"action" => "scale", "queue" => queue, "scale" => scale} <- Jason.decode!(payload) do
      true = :ets.insert(table, {{:queue, queue, :limit}, scale})
    end

    {:noreply, state}
  end

  # Helpers

  defp fetch_queue_limits(%State{queues: queues, table: table}) do
    for {queue, limit} <- queues do
      true = :ets.insert(table, {{:queue, to_string(queue), :limit}, limit})
    end
  end

  defp fetch_queue_counts(%State{repo: repo, table: table}) do
    reset_counts(table, {:queue, :_, :_})

    for {queue, state, count} <- Query.queue_counts(repo) do
      short =
        case state do
          "available" -> :avail
          "executing" -> :execu
        end

      true = :ets.insert(table, {{:queue, queue, short}, count})
    end
  end

  defp fetch_state_counts(%State{repo: repo, table: table}) do
    reset_counts(table, {:state, :_})

    for {state, count} <- Query.state_counts(repo) do
      true = :ets.insert(table, {{:state, state}, count})
    end
  end

  defp fetch_node_counts(%State{repo: repo, table: table}) do
    reset_counts(table, {:node, :_, :_})

    for {node, queue, count} <- Query.node_counts(repo) do
      true = :ets.insert(table, {{:node, node, queue}, count})
    end
  end

  defp state_to_incr(new, _ol, new), do: 1
  defp state_to_incr(_ne, old, old), do: -1
  defp state_to_incr(_ne, _ol, _an), do: 0

  defp reset_counts(table, match) do
    :ets.select_delete(table, [{match, [], [true]}])
  end
end
