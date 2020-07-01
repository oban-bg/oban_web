# Installation

_Before continuing, be sure you have Oban up and running in your app!_

`Oban.Web` is built with [Phoenix Live View][plv] and it relies on a working
installation of it in your application. If you don't have Live View
installed, follow [these instructions][lvi] to get started.

`Oban.Web` is delivered as a hex package named `oban_web`, which is published
privately under the `oban` organization. The package is entirely self
contained—it doesn’t hook into your asset pipeline at all.

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
{:oban_web, "~> 2.0.0-alpha.1", organization: "oban"}
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

### Trouble installing? Have questions?

Take a look at the [troubleshooting][faq] guide to see if your issue is covered.
If not, or if need any help, stop by the #oban channel in [Elixir Slack][sla].

[plv]: https://github.com/phoenixframework/phoenix_live_view
[lvi]: https://github.com/phoenixframework/phoenix_live_view#installation
[faq]: web_troubleshooting.html
[sla]: https://elixir-slackin.herokuapp.com
[ba]: https://hexdocs.pm/basic_auth/readme.html
