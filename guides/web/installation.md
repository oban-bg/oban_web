# Installation

_Before continuing, be sure you have Oban up and running in your app!_

`Oban.Web` is built with [Phoenix Live View][plv] and it relies on a working
installation of it in your application. If you don't have Live View
installed, follow [these instructions][lvi] to get started.

`Oban.Web` is delivered as a hex package named `oban_web`, which is published
privately to our self-hosted package repository. The package is entirely self
contained—it doesn't hook into your asset pipeline at all.

Before you can pull the package into your application you need to add a new
`oban` hex repo. First, grab the `OBAN_KEY_FINGERPRINT` and `OBAN_LICENSE_KEY`
from your account page. Then, run the following `mix hex.repo` command:

```console
mix hex.repo add oban https://getoban.pro/repo \
  --fetch-public-key $OBAN_KEY_FINGERPRINT \
  --auth-key $OBAN_LICENSE_KEY
```

⚠️ _You'll also need to authenticate on any other development machines, build
servers and CI instances. There are also guides to help with authenticating on
[Gigalixir][gi] and [Heroku][he]_.

Now that you're authenticated you're ready to add `oban_web` as a dependency for
your application. Open `mix.exs` and add the following line:

```elixir
{:oban_web, "~> 2.6.2", repo: "oban"}
```

Now fetch your dependencies:

```console
$ mix deps.get
```

This will fetch both `oban_web` and `oban_pro`, if you haven't already installed
`oban_pro`.

The `Gossip` plugin and the `Stats` plugin are necessary for the dashboard to
function properly. Add them to your Oban configuration in `config.exs`:

```elixir
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [alpha: 10, gamma: 10, delta: 10],
  plugins: [
    Gossip,
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

If your application is hosted in an environment that doesn't support websockets
you can use longpolling as an alternate transport. To start, make sure that your
live socket is configured for longpolling:

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

## Content Security Policy

To secure the dashboard, or comply with an existing CSP within your application,
you can specify nonce keys for images, scripts and styles.

You'll configure the CSP nonce assign key in your router, where the dashboard is
mounted. For example, to use a single nonce for all three asset types:

```elixir
oban_dashboard("/oban", csp_nonce_assign_key: :my_csp_nonce)
```

That instructs the dashboard to extract a generated nonce from the `assigns` map
on the plug connection, at the `:my_csp_nonce` key.

Instead, you can specify different keys for each asset type:

```elixir
oban_dashboard("/oban",
  csp_nonce_assign_key: %{
    img: :img_csp_nonce,
    style: :style_csp_nonce,
    script: :script_csp_nonce
  }
)
```

Note that using the CSP is entirely optional.

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
[gi]: pro_installation.html#authorizing-on-gigalixir
[he]: pro_installation.html#authorizing-on-heroku
