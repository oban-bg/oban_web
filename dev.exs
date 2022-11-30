# Development server for Oban Web

defmodule ObanDemo.Repo do
  use Ecto.Repo, otp_app: :oban_web, adapter: Ecto.Adapters.Postgres
end

defmodule ObanDemo.Migration0 do
  use Ecto.Migration

  def up do
    Oban.Migrations.up()
    Oban.Pro.Migrations.Producers.up()
    Oban.Pro.Migrations.DynamicCron.up()
    Oban.Pro.Migrations.DynamicQueues.up()
  end

  def down do
    Oban.Pro.Migrations.DynamicQueues.down()
    Oban.Pro.Migrations.DynamicCron.down()
    Oban.Pro.Migrations.Producers.down()
    Oban.Migrations.down()
  end
end

defmodule ObanDemo.Router do
  use Phoenix.Router

  import Oban.Web.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/" do
    pipe_through :browser

    oban_dashboard "/oban"
  end
end

defmodule ObanDemo.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_web

  socket "/live", Phoenix.LiveView.Socket
  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.Session,
    store: :cookie,
    key: "_oban_web_key",
    signing_salt: "/VEDsdfsffMnp5"

  plug ObanDemo.Router
end

# Configuration

Application.put_env(:oban_web, ObanDemo.Endpoint,
  check_origin: false,
  debug_errors: true,
  http: [port: 4000],
  live_view: [signing_salt: "eX7TFPY6Y/+XQ1o2pOUW3DjgAoXGTAdX"],
  pubsub_server: ObanDemo.PubSub,
  secret_key_base: "jAu3udxm+8tIRDXLLKo+EupAlEvdLsnNG82O8e9nqylpBM9gP8AjUnZ4PWNttztU",
  url: [host: "localhost"],
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/oban/web/components/.*(ex)$"
    ]
  ]
)

Application.put_env(:oban_web, ObanDemo.Repo, url: "postgres://localhost:5432/oban_web_dev")
Application.put_env(:phoenix, :serve_endpoints, true)

oban_opts = [
  engine: Oban.Pro.Queue.SmartEngine,
  repo: ObanDemo.Repo,
  peer: Oban.Peers.Global,
  notifier: Oban.Notifiers.PG,
  queues: [
    analysis: 20,
    default: 30,
    events: 15,
    exports: [global_limit: 8],
    mailers: [local_limit: 10, rate_limit: [allowed: 90, period: 15]],
    media: [local_limit: 10, rate_limit: [allowed: 20, period: 60, partition: [fields: [:worker]]]]
  ],
  plugins: [
    {Oban.Pro.Plugins.DynamicLifeline, []},
    {Oban.Pro.Plugins.DynamicPruner, mode: {:max_age, {1, :days}}}
  ]
]

supervise = fn ->
  children = [
    {ObanDemo.Repo, []},
    {Phoenix.PubSub, [name: ObanDemo.PubSub, adapter: Phoenix.PubSub.PG2]},
    {Oban, oban_opts},
    {ObanDemo.Endpoint, []}
  ]

  repo_conf = ObanDemo.Repo.config()

  Ecto.Adapters.Postgres.storage_up(repo_conf)
  ObanDemo.Repo.__adapter__().storage_down(repo_conf)
  ObanDemo.Repo.__adapter__().storage_up(repo_conf)

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)

  Ecto.Migrator.run(ObanDemo.Repo, [{0, ObanDemo.Migration0}], :up, all: true)

  Process.sleep(:infinity)
end

supervise
|> Task.async()
|> Task.await(:infinity)
