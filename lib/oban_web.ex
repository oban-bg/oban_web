defmodule ObanWeb do
  @moduledoc false

  use Supervisor

  alias Oban.Config
  alias ObanWeb.Stats

  @spec start_link([Oban.option()]) :: Supervisor.on_start()
  def start_link(opts) when is_list(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)

    conf = Config.new(opts)

    Supervisor.start_link(__MODULE__, conf, name: name)
  end

  @impl Supervisor
  def init(%Config{} = conf) do
    children = [
      {Stats, name: Module.concat(conf.name, "Stats"), queues: conf.queues, repo: conf.repo}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
