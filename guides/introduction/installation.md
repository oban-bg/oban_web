# Installation

Oban Web is delivered as a hex package named `oban_web`. The package is entirely self contained—it
doesn't hook into your asset pipeline at all.

## Prerequisites

1. Ensure Oban is installed for your application. It's probably there already, but just in case,
   follow [these instructions][oi] to get started.

2. Ensure [Phoenix Live View][plv] is installed and working in your application. If you don't have
   Live View, follow [these instructions][lvi] to get started.

## Configuration

Add `oban_web` as a dependency for your application. Open `mix.exs` and add the following line:

```elixir
{:oban_web, "~> 2.11"}
```

Now fetch your dependencies:

```bash
mix deps.get
```

This will fetch both `oban_web` and `oban_met`.

After fetching the package you'll use the `Oban.Web.Router` to mount the dashboard within your
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

After you've verified that the dashboard is loading you'll probably want to restrict access to the
dashboard via authentication, either with a [custom resolver's][ac] access controls or [Basic
Auth][ba].

### Switch to the PG Notifier

PubSub notifications are essential to Web's operation. Oban uses a Postgres based notifier for
PubSub by default. That notifier is convenient when getting started, but it has a hard 8kb
restriction on PubSub messages and busy systems may exceed that occasionally.

To get the most out of Web's metrics, you should switch to the PG (Process Groups) based notifier
built on Distributed Erlang.

> #### Clustering Required {: .info}
>
> The PG notifier **requires that your app is clustered** together. Otherwise, notifications are
> local to the current node and **you won't see accurate counts or activity metrics**.

```diff
 config :my_app, Oban,
+  notifier: Oban.Notifiers.PG,
   repo: MyApp.Repo,
   ...
```

### Usage with Web and Worker Nodes

To use Web in an application that also runs on non-web nodes, i.e. a system with separate "web"
and "worker" applications, you must explicitly include `oban_met` as a dependency for "workers".

```elixir
{:oban_met, "~> 0.1", repo: :oban}
```

## Customization

Web customization is done through the `Oban.Web.Resolver` behaviour. It allows you to enable
access controls, control formatting, and provide query limits for filtering and searching. Using a
custom resolver is entirely optional, but you should familiarize yourself with the default limits
and functionality.

Installation is complete and you're all set! Start your Phoenix server, point your browser to
where you mounted Oban and start monitoring your jobs.

## Next Steps

* Configure the dashboard connection or mount additional dashboards with the `Oban.Web.Router`

* Configure dashboard behavior with access controls, query limits, and formatting with
  `Oban.Web.Resolver`

* Attach logging and hook into telemetry events with `Oban.Web.Telemetry`

[plv]: https://github.com/phoenixframework/phoenix_live_view
[lvi]: https://github.com/phoenixframework/phoenix_live_view#installation
[ac]: Oban.Web.Resolver.html#c:resolve_access/1
[ba]: https://hexdocs.pm/basic_auth/readme.html
[oi]: installation.html
