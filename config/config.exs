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
    version: "3.1.6",
    default: [
      args: ~w(
        --config=tailwind.config.js
        --minify
        --input=css/app.css
        --output=../priv/static/app.css
      ),
      cd: Path.expand("../assets", __DIR__)
    ]
end

config :logger, level: :warn
config :logger, :console, format: "[$level] $message\n"

config :phoenix, json_library: Jason, stacktrace_depth: 20

config :oban_met, auto_start: false

config :oban_web, ecto_repos: [Oban.Web.Repo]

config :oban_web, Oban.Web.Repo,
  priv: "test/support/",
  url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/oban_web_test",
  pool: Ecto.Adapters.SQL.Sandbox
