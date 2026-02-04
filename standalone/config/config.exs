import Config

config :oban_dashboard, ObanDashboard.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: ObanDashboard.ErrorHTML], layout: false],
  pubsub_server: ObanDashboard.PubSub,
  live_view: [signing_salt: "oban_dashboard"]

config :phoenix, :json_library, JSON

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
