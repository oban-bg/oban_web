# ObanWeb

A live dashboard for monitoring and operating Oban.

## Installation

This project relies on a working install of Oban as well as Phoenix.

1. Install [Phoenix Live View][plv]

2. Authenticate with the `oban` [organization on hex][hpm], this is required to pull down the
   `ObanWeb` package locally and in CI.

3. Add `ObanWeb` as a dependency in your `mix.exs` file:

  ```
  {:oban_web, "~> 0.4", organization: "oban"}
  ```
4. Add `ObanWeb` as a child within your application module (note that it is passed the same
   options as `Oban`):

  ```
  def start(_type, _args) do
    oban_opts = Application.get_env(:my_app, Oban)

    children = [
      MyApp.Repo,
      MyApp.Endpoint,
      {Oban, oban_opts},
      {ObanWeb, oban_opts}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]

    Supervisor.start_link(children, opts)
  end
  ```
5. Mount the dashboard within your Phoenix router:

  ```
  scope "/" do
    pipe_through :browser

    live "/oban", ObanWeb.DashboardLive, layout: {ObanWeb.LayoutView, "app.html"}
  end
  ```

  Here we're using `"/oban"` as the mount point, but it can be anywhere you like.
6. Run `ObanWeb` migrations to create indexes and setup notifications:

  ```
  defmodule MyApp.Repo.Migrations.UpgradeObanWeb do
    use Ecto.Migration

    defdelegate up, to: ObanWeb.Migrations
    defdelegate down, to: ObanWeb.Migrations
  end
  ```

7. Optionally increase the search tolerance for full text queries by setting an
   `after_connect` hook on your repo:

  ```
  after_connect: {Postgrex, :query!, ["SELECT set_limit($1)", [0.1]]}
  ```

[plv]: https://github.com/phoenixframework/phoenix_live_view#installation
[hpm]: https://hex.pm/docs/private#authenticating-on-ci-and-build-servers
