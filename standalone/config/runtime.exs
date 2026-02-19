import Config

port = String.to_integer(System.get_env("PORT", "4000"))

config :oban_dash, ObanDash.Repo,
  url: System.fetch_env!("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "5")),
  show_sensitive_data_on_connection_error: true,
  ssl: String.to_existing_atom(System.get_env("SSL", "false")) in ["true", "1"],
  ssl_opts: [verify_mode: String.to_existing_atom(System.get_env("SSL_VERIFY_MODE", "verify_peer"))]

config :oban_dash, ObanDash.Endpoint,
  http: [port: port, ip: {0, 0, 0, 0}],
  url: [host: System.get_env("HOST", "localhost")],
  secret_key_base: "eGKAe6cMdfeEDqQcw8LVQOExX/dWMfGIc3Ti4Pj+m5Hikugq7GdHIJWV8NAqrlr1",
  server: true