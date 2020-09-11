# Oban.Web

A live dashboard for monitoring and operating Oban.

## Contributing

Working on Oban.Web has the following dependencies:

1. Elixir 1.8+
2. Erlang/OTP 21.0+
3. Postgres 10+
4. Node

We'll assume you have Elixir/Erlang/PostgreSQL running already (because you
wouldn't be reading this otherwise!).

#### Update Assets

Run `make watch` when you need to change js or css assets.

#### Tests & Code Quality

To ensure a commit passes CI you should run `MIX_ENV=test mix ci` locally, which
executes the following commands:

* Check formatting (`mix format --check-formatted`)
* Lint with Credo (`mix credo --strict`)
* Run all tests (`mix test --raise`)
