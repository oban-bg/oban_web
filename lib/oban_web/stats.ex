defmodule ObanWeb.Stats do
  @moduledoc false

  use GenServer

  alias Oban.Notifier
  alias ObanWeb.Query

  @insert "oban_insert"
  @update "oban_update"

  defmodule State do
    @moduledoc false

    defstruct [:queues, :repo, :table, refresh_interval: :timer.seconds(60)]
  end

  def start_link(opts) when is_list(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def for_queues(name \\ __MODULE__) do
    count_stats = :ets.select(name, [{{{:queue, :"$1", :count}, :"$2"}, [], [:"$$"]}])

    Map.new(count_stats, fn [key, val] -> {key, val} end)
  end

  def for_states(name \\ __MODULE__) do
    count_stats = :ets.select(name, [{{{:state, :"$1"}, :"$2"}, [], [:"$$"]}])

    Map.new(count_stats, fn [key, val] -> {key, val} end)
  end

  @impl GenServer
  def init(opts) do
    table = :ets.new(opts[:name], [:protected, :named_table, read_concurrency: true])
    state = %State{queues: opts[:queues], repo: opts[:repo], table: table}

    {:ok, state, {:continue, :start}}
  end

  @impl GenServer
  def handle_continue(:start, state) do
    fetch_queue_counts(state)
    fetch_state_counts(state)

    {:ok, _ref} = :timer.send_interval(state.refresh_interval, :refresh)

    :ok = Notifier.listen(@insert)
    :ok = Notifier.listen(@update)

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:refresh, state) do
    fetch_state_counts(state)
    fetch_queue_counts(state)

    {:noreply, state}
  end

  def handle_info({:notification, _, _, @insert, payload}, %State{table: table} = state) do
    %{"state" => job_state, "queue" => job_queue} = Jason.decode!(payload)

    :ets.update_counter(table, {:state, job_state}, 1)

    if job_state == "available" do
      :ets.update_counter(table, {:queue, job_queue, :count}, 1)
    end

    {:noreply, state}
  end

  def handle_info({:notification, _, _, @update, payload}, %State{table: table} = state) do
    %{"queue" => queue, "new_state" => new, "old_state" => old} = Jason.decode!(payload)

    :ets.update_counter(table, {:state, old}, -1)
    :ets.update_counter(table, {:state, new}, 1)

    incr =
      cond do
        new == "available" -> 1
        old == "available" -> -1
        true -> 0
      end

    :ets.update_counter(table, {:queue, queue, :count}, incr)

    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp fetch_queue_counts(%State{queues: queues, repo: repo, table: table}) do
    queue_names = for {queue, _limit} <- queues, do: to_string(queue)

    for {queue, count} <- Query.queue_counts(queue_names, repo) do
      true = :ets.insert(table, {{:queue, queue, :count}, count})
    end
  end

  defp fetch_state_counts(%State{repo: repo, table: table}) do
    for {state, count} <- Query.state_counts(repo) do
      true = :ets.insert(table, {{:state, state}, count})
    end
  end
end
