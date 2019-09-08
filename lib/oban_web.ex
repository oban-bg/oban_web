defmodule ObanWeb do
  @moduledoc false

  use Supervisor

  alias ObanWeb.Stats

  @spec start_link([Oban.option()]) :: Supervisor.on_start()
  def start_link(opts) when is_list(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl Supervisor
  def init(opts) do
    children = [{Stats, opts}]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
