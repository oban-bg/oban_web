# Installation

Oban Web is delivered as a hex package named `oban_web`. The package is entirely self contained—it
doesn't hook into your asset pipeline at all.

There are three installation mechanisms available:

- [Semi-Automatic Installation](#semi-automatic-installation) using an igniter powered mix task
- [Igniter Installation](#igniter-installation) fully automatic installation using igniter
- [Manual Installation](#manual-installation) add Oban Web and handle all steps manually

## Semi-Automatic Installation

You can use the `oban_web.install` task without the `igniter.install` escript available.
First, add `oban_web` and `igniter` to your deps in `mix.exs`:

```elixir
{:oban_web, "~> 2.11"},
{:igniter, "~> 0.5", only: [:dev]},
```

Run `mix deps.get` to fetch `oban_web`, then run the install task:

```bash
mix oban_web.install
```

This will automate all of the manual setup steps for you!

## Igniter Installation

For projects that have [igniter][igniter] available, Oban Web can be installed and configured with
a single command:

```bash
mix igniter.install oban_web
```

that will add the latest version of `oban_web` to your dependencies before running the installer,
then mount it as `/oban` within the `:dev_routes` conditional.

## Manual Installation

Before installing Oban Web, ensure you have:

1. **Oban** - Verify Oban is installed in your application. If not, follow [these
  instructions][oi] to get started.

2. **Phoenix Live View** - Ensure [Phoenix Live View][plv] is installed and working. If you
  don't have Live View yet, follow [these instructions][lvi].

Add `oban_web` to your list of deps in `mix.exs`:

```elixir
{:oban_web, "~> 2.11"}
```

Then fetch the dependencies:

```bash
mix deps.get
```

After fetching the package, use the `Oban.Web.Router` to mount the dashboard within your
application's `router.ex`:

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

Here we're using `"/oban"` as the mount point, but it can be anywhere you like. See the
`Oban.Web.Router` docs for additional options.

## Post-Installation

After installation (by any method), you should consider the following configuration steps:

### Secure Dashboard Access

After verifying that the dashboard is loading, it's recommended to restrict access to it, either
with a [custom resolver's][ac] access controls or [Basic Auth][ba].

### Switch to the PG Notifier

PubSub notifications are essential to Web's operation. Oban uses a Postgres based notifier for
PubSub by default. This notifier is convenient when getting started, but it has a hard 8kb
restriction on PubSub messages and busy systems may exceed that occasionally.

To get the most out of Web's metrics, you should switch to the PG (Process Groups) based notifier
built on Distributed Erlang.

```diff
 config :my_app, Oban,
+  notifier: Oban.Notifiers.PG,
   repo: MyApp.Repo,
   ...
```

> #### Clustering Required {: .info}
>
> The PG notifier **requires that your app is clustered** together. Otherwise, notifications are
> local to the current node and **you won't see accurate counts or activity metrics**.

### Split Web and Worker Nodes

If your application runs on separate "web" and "worker" nodes, you must explicitly include
`oban_met` as a dependency for the "worker" nodes:

```elixir
{:oban_met, "~> 1.0"}
```

### Customize the Dashboard

Web customization is done through the `Oban.Web.Resolver` behaviour. It allows you to enable
access controls, control formatting, and provide query limits for filtering and searching. Using a
custom resolver is optional, but you should familiarize yourself with the default limits
and functionality.

## Next Steps

Installation is complete and you're all set! Start your Phoenix server, point your browser to
`/oban` and start monitoring your jobs.

* Configure dashboard behavior with access controls, query limits, and formatting using
  `Oban.Web.Resolver`

* Attach logging and hook into telemetry events with `Oban.Web.Telemetry`

[igniter]: https://hex.pm/packages/igniter
[plv]: https://github.com/phoenixframework/phoenix_live_view
[lvi]: https://github.com/phoenixframework/phoenix_live_view#installation
[ac]: Oban.Web.Resolver.html#c:resolve_access/1
[ba]: https://hexdocs.pm/basic_auth/readme.html
[oi]: installation.html
