defmodule Oban.Web.Plugins.Stats do
  @moduledoc false

  @behaviour Oban.Plugin

  use GenServer

  @impl Oban.Plugin
  def start_link(opts) do
    IO.warn("Oban.Web.Plugins.Stats is no longer needed, remove it from your plugins")

    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(_opts), do: :ignore

  @impl Oban.Plugin
  def validate(_opts), do: :ok
end
