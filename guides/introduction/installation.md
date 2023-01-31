# Installation

Oban Web is delivered as a hex package named `oban_web`, which is published
privately to our self-hosted package repository. The package is entirely self
contained—it doesn't hook into your asset pipeline at all.

## Prerequisites

1. Ensure Oban is installed for your application. It's probably there already,
   but just in case, follow [these instructions][oi] to get started.

2. Ensure [Phoenix Live View][plv] is installed and working in your application.
   If you don't have Live View, follow [these instructions][lvi] to get started.

3. Ensure you're running Erlang/OTP v23.3.4.5, v24.0.4, or later. Older Erlang/OTP
   versions have an expired CA root certificate that doesn't work with Let's
   Encrypt certificates.

4. Ensure you're running `hex` v1.0.0 or later, via `mix local.hex --force`

## Authentication

Before you can pull the package into your application you need to add a new
`oban` hex repo. First, grab the `OBAN_KEY_FINGERPRINT` and `OBAN_LICENSE_KEY`
from your account page.

Then, run the following `mix hex.repo` command:

```console
mix hex.repo add oban https://getoban.pro/repo \
  --fetch-public-key $OBAN_KEY_FINGERPRINT \
  --auth-key $OBAN_LICENSE_KEY
```

Now your local environment is configured to pull from the `oban` repo!

#### Authenticating For Production

There are individual guides to help with building [Docker Images][di],
authenticating on [Gigalixir][gi], and [Heroku][he].

#### Authenticating For CI

You'll also need to authenticate on any other development machines, build servers and
CI/CD instances. For example, to authorize for GitHub Actions (or any other YAML
based CI service) using `secrets` storage:

```yaml
- name: Authorize Oban
  run: |
    mix hex.repo add oban https://getoban.pro/repo \
      --fetch-public-key ${{secrets.oban_key_fingerprint}} \
      --auth-key ${{secrets.oban_license_key}}
```

## Configuration

Now that you're authenticated you're ready to add `oban_web` as a dependency for
your application. Open `mix.exs` and add the following line:

```elixir
{:oban_web, "~> 2.9", repo: "oban"}
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
    Oban.Plugins.Gossip,
    Oban.Web.Plugins.Stats
  ]
```

### Advanced Configuration

Some applications have dedicated `web` and `worker` nodes, where only the
`worker` nodes execute jobs. In that arrangement, the `web` node won't run any
queues, but it still needs to insert jobs, run `Oban` commands, and host the
dasbhoard.

The ideal, minimal, configuration only includes the `Stats` plugin and declares
that a `web` node shouldn't be the leader with `peer: false`:

```elixir
# Web Config
config :my_app, Oban,
  peer: false,
  plugins: [Oban.Web.Plugins.Stats],
  queues: []
```

Conversely, workers need to broadcast queue activity through `Gossip`, but they
don't need to run `Stats` for the dashboard:

```elixir
# Worker Config
config :my_app, Oban,
  plugins: [
    Oban.Plugins.Gossip,
    ...
  ],
  queues: [...]
```

## Mounting the Dashboard

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
For more advanced usage, the [mounting guide][mo] explains how you can run
multiple dashboards or customize the connection.

After you've verified that the dashboard is loading you'll probably want to
restrict access to the dashboard via authentication, e.g. with [Basic Auth][ba].

## Installation Complete!

Installation is complete and you're all set! Start your Phoenix server, point
your browser to where you mounted Oban and start monitoring your jobs.

Continue on to the [customizing guide][cu] to learn about resolvers for
setting defaults, authorization controls, and custom formatting.

[plv]: https://github.com/phoenixframework/phoenix_live_view
[lvi]: https://github.com/phoenixframework/phoenix_live_view#installation
[ba]: https://hexdocs.pm/basic_auth/readme.html
[di]: https://getoban.pro/docs/pro/docker.html
[gi]: https://getoban.pro/docs/pro/gigalixir.html
[he]: https://getoban.pro/docs/pro/heroku.html
[cu]: customizing.html
[oi]: installation.html
[mo]: mounting.html
