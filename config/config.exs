use Mix.Config

config :phoenix, :json_library, Jason

config :oban_web, ecto_repos: [ObanWeb.Repo]

config :oban_web, ObanWeb.Endpoint,
  http: [port: 4002],
  live_view: [signing_salt: "eX7TFPY6Y/+XQ1o2pOUW3DjgAoXGTAdX"],
  pubsub: [name: ObanWeb.PubSub, adapter: Phoenix.PubSub.PG2],
  secret_key_base: "jAu3udxm+8tIRDXLLKo+EupAlEvdLsnNG82O8e9nqylpBM9gP8AjUnZ4PWNttztU",
  server: false,
  url: [host: "localhost"]

config :oban_web, ObanWeb.Repo,
  priv: "test/support/",
  url: System.get_env("DATABASE_URL") || "postgres://localhost:5432/oban_web_test",
  pool: Ecto.Adapters.SQL.Sandbox
