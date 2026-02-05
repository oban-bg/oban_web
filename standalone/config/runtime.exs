import Config

port = String.to_integer(System.get_env("PORT", "4000"))

config :oban_dash, ObanDash.Repo,
  url: System.fetch_env!("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "5")),
  show_sensitive_data_on_connection_error: true

config :oban_dash, ObanDash.Endpoint,
  http: [port: port, ip: {0, 0, 0, 0}],
  url: [host: System.get_env("HOST", "localhost")],
  secret_key_base: "eGKAe6cMdfeEDqQcw8LVQOExX/dWMfGIc3Ti4Pj+m5Hikugq7GdHIJWV8NAqrlr1",
  server: true

config :oban_dash,
  oban_prefix: System.get_env("OBAN_PREFIX", "public"),
  read_only: System.get_env("OBAN_READ_ONLY", "false") == "true",
  basic_auth_user: System.get_env("BASIC_AUTH_USER"),
  basic_auth_pass: System.get_env("BASIC_AUTH_PASS")

config :logger, level: String.to_existing_atom(System.get_env("LOG_LEVEL", "info"))
