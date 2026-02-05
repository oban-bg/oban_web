import Config

config :oban_dash, ObanDash.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: ObanDash.ErrorHTML], layout: false],
  pubsub_server: ObanDash.PubSub,
  live_view: [signing_salt: "oban_dash"]

config :phoenix, :json_library, JSON

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
