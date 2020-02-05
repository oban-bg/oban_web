defmodule ObanWeb do
  @moduledoc false

  use Supervisor

  alias ObanWeb.{Config, Stats}

  @spec start_link([Oban.option()]) :: Supervisor.on_start()
  def start_link(opts) when is_list(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    conf = Config.new(opts)

    Supervisor.start_link(__MODULE__, conf, name: name)
  end

  def init(%Config{} = conf) do
    children = [{Config, conf: conf, name: Config}, {Stats, conf: conf, name: Stats}]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
