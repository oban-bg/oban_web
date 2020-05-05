use Mix.Config

config :logger, level: :warn
config :logger, :console, format: "[$level] $message\n"

config :phoenix, json_library: Jason, stacktrace_depth: 20

config :oban_web, ecto_repos: [ObanWeb.Repo]

config :oban_web, ObanWeb.Repo,
  priv: "test/support/",
  url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/oban_web_test",
  pool: Ecto.Adapters.SQL.Sandbox
