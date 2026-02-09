import Config

if config_env() == :dev do
  config :esbuild,
    version: "0.14.41",
    default: [
      args: ~w(
        assets/js/app.js
        --bundle
        --minify
        --outdir=priv/static/
      )
    ]

  config :tailwind,
    version: "4.1.0",
    default: [
      args: ~w(
        --minify
        --input=css/app.css
        --output=../priv/static/app.css
      ),
      cd: Path.expand("../assets", __DIR__)
    ]
end

if config_env() == :test do
  config :oban_web,
    ecto_repos: [
      Oban.Web.Repo,
      Oban.Web.SQLiteRepo,
      Oban.Web.MyXQLRepo
    ]

  config :oban_web, Oban.Web.Repo,
    pool: Ecto.Adapters.SQL.Sandbox,
    priv: "test/support/postgres",
    show_sensitive_data_on_connection_error: true,
    stacktrace: true,
    url: System.get_env("POSTGRES_URL") || "postgres://localhost:5432/oban_web_test"

  config :oban_web, Oban.Web.SQLiteRepo,
    database: "priv/oban_web_test.db",
    priv: "test/support/sqlite",
    stacktrace: true,
    temp_store: :memory

  config :oban_web, Oban.Web.MyXQLRepo,
    priv: "test/support/mysql",
    pool: Ecto.Adapters.SQL.Sandbox,
    show_sensitive_data_on_connection_error: true,
    stacktrace: true,
    url: System.get_env("MYSQL_URL") || "mysql://root@localhost:3306/oban_web_test"
end

config :elixir, :time_zone_database, Tz.TimeZoneDatabase

config :logger, level: :warning
config :logger, :console, format: "[$level] $message\n"

config :phoenix, stacktrace_depth: 20

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true
