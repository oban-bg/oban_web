defmodule ObanWeb do
  @moduledoc false

  use Supervisor

  alias ObanWeb.{Config, Stats}

  @spec start_link([Oban.option()]) :: Supervisor.on_start()
  def start_link(opts) when is_list(opts) do
    conf = Config.new(opts)

    Supervisor.start_link(__MODULE__, conf, name: conf.name)
  end

  def init(%Config{name: name} = conf) do
    table = :ets.new(name, [:public, :named_table, read_concurrency: true])

    children = [
      {Config, conf: conf, name: Module.concat(name, "Config")},
      {Stats, conf: conf, name: Module.concat(name, "Stats"), table: table}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
