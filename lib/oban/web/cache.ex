defmodule Oban.Web.Cache do
  @moduledoc false

  use GenServer

  defstruct [:name, purge_interval: :timer.seconds(300)]

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)

    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def fetch(name \\ __MODULE__, key, fun) do
    if cache_enabled?() do
      case :ets.lookup(name, key) do
        [{^key, val}] ->
          val

        [] ->
          tap(fun.(), &:ets.insert(name, {key, &1}))
      end
    else
      fun.()
    end
  end

  @impl GenServer
  def init(opts) do
    state = struct!(__MODULE__, opts)

    :ets.new(state.name, [:set, :public, :compressed, :named_table])

    {:ok, schedule_purge(state)}
  end

  @impl GenServer
  def handle_info(:purge, state) do
    :ets.delete_all_objects(state.name)

    {:noreply, schedule_purge(state)}
  end

  defp cache_enabled? do
    Process.get(:cache_enabled, Application.get_env(:oban_web, :cache))
  end

  defp schedule_purge(state) do
    Process.send_after(self(), :purge, state.purge_interval)

    state
  end
end
