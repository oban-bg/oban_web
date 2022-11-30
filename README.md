# Oban Web

A live dashboard for monitoring and operating Oban.

## Contributing

Working on Oban.Web has the following dependencies:

1. Elixir 1.13+
2. Erlang/OTP 24.0+
3. Postgres 11+

We'll assume you have Elixir/Erlang/PostgreSQL running already (because you
wouldn't be reading this otherwise!).

A single file development server is built in. Run it with `mix dev`.

### Update Assets

Run `mix assets.build` when you need to change js or css assets.

### Tests & Code Quality

To ensure a commit passes CI you should run `mix test.ci` locally.
