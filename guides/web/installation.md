# Installation

_Before continuing, be sure you have Oban up and running in your app!_

`Oban.Web` is built with [Phoenix Live View][plv] and it relies on a working
installation of it in your application. If you don't have Live View
installed, follow [these instructions][lvi] to get started.

`Oban.Web` is delivered as a hex package named `oban_web`, which is published
privately under the `oban` organization. The package is entirely self
contained—it doesn't hook into your asset pipeline at all.

Before you can pull the package into your application you need to authenticate
with the `oban` organization.

```console
$ mix hex.organization auth oban --key YOUR_OBAN_LICENSE_KEY
```

⚠️ _You'll also need to authenticate on any other development machines, build
servers and CI instances._

Now that you're authenticated you're ready to add `oban_web` as a dependency for
your application. Open `mix.exs` and add the following line:

```elixir
{:oban_web, "~> 2.5.1", organization: "oban"}
```

Now fetch your dependencies:

```console
$ mix deps.get
```

This will fetch both `oban_web` and `oban_pro`, if you haven't already installed
`oban_pro`.

Both the pro `Lifeline` plugin and the web `Stats` plugins are necessary for the
dashboard to function properly. Add them to your Oban configuration in
`config.exs`:

```elixir
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [alpha: 10, gamma: 10, delta: 10],
  plugins: [
    Oban.Pro.Plugins.Lifeline,
    Oban.Web.Plugins.Stats
  ]
```

After configuration you can mount the dashboard within your application's
`router.ex`:

```elixir
# lib/my_app_web/router.ex
use MyAppWeb, :router

import Oban.Web.Router

...

scope "/" do
  pipe_through :browser

  oban_dashboard "/oban"
end
```

Here we're using `"/oban"` as the mount point, but it can be anywhere you like.
After you've verified that the dashboard is loading you'll probably want to
restrict access to the dashboard via authentication, e.g. with [Basic Auth][ba].

Installation is complete and you're all set! Start your Phoenix server, point
your browser to where you mounted Oban and start monitoring your jobs.

## Running Multiple Dashboards

Applications that run multiple Oban instances can mount a dashboard for each
instance. Set the mounted dashboard's `:oban_name` to match the corresponding
supervision tree's name. For example, given two configured Oban instances,
`Oban` and `MyAdmin.Oban`:

```elixir
config :my_app, Oban,
  repo: MyApp.Repo,
  name: Oban,
  ...

config :my_admin, Oban,
  repo: MyAdmin.Repo,
  name: MyAdmin.Oban,
  ...
```

You can then mount both dashboards in your router:

```elixir
scope "/" do
  pipe_through :browser

  oban_dashboard "/oban", oban_name: Oban
  oban_dashboard "/oban/admin", oban_name: MyAdmin.Oban
end
```

Note that the default name is `Oban`, setting `oban_name: Oban` in the example
above was purely for demonstration purposes.

## Using LongPolling

If you're application is hosted in an environment that doesn't support
websockets you can use longpolling as an alternate transport. To start, make
sure that your live socket is configured for longpolling:

```elixir
socket "/live", Phoenix.LiveView.Socket,
  longpoll: [connect_info: [session: @session_options], log: false]
```

Then specify "longpoll" as your transport:

```elixir
scope "/" do
  pipe_through :browser

  oban_dashboard "/oban", transport: "longpoll"
end
```

## Customizing with a Resolver Callback Module

Implementing a `Oban.Web.Resolver` callback module allows you to customize the
dashboard per-user, i.e. setting access controls or the default refresh rate.

As a simple example, let's define a module that makes the dashboard read only:

```elixir
defmodule MyApp.Resolver do
  @behaviour Oban.Web.Resolver

  @impl true
  def resolve_access(_user), do: :read_only
end
```

Then specify `MyApp.Resolver` as your resolver:

```elixir
scope "/" do
  pipe_through :browser

  oban_dashboard "/oban", resolver: MyApp.Resolver
end
```

See [Customizing the Dashboard][cus] for details on the `Resolver` behaviour.

## Integrating with Telemetry

Oban Web uses `Telemetry` to provide instrumentation and to power logging
of dashboard activity. See the [Telemetry][tel] guide for a breakdown of emitted
events and how to use the default logger.

### Trouble installing? Have questions?

Take a look at the [troubleshooting][faq] guide to see if your issue is covered.
If not, or if you need any help, stop by the #oban channel in [Elixir Slack][sla].

[plv]: https://github.com/phoenixframework/phoenix_live_view
[lvi]: https://github.com/phoenixframework/phoenix_live_view#installation
[faq]: web_troubleshooting.html
[cus]: web_customizing.html
[tel]: web_telemetry.html
[sla]: https://elixir-slackin.herokuapp.com
[ba]: https://hexdocs.pm/basic_auth/readme.html
