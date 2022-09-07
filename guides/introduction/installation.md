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

#### Authenticating Other Systems

You'll also need to authenticate on any other development machines, build
servers and CI/CD instances. There are also guides to help with building
[Docker Images][di], authenticating on [Gigalixir][gi] and [Heroku][he].

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

This will fetch both `oban_web` and `oban_met`, if you haven't already installed
`oban_met` through `oban_pro`.

After fetching the package you can mount the dashboard within your application's
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

If you need any help, stop by the #oban channel in [Elixir Slack][sla].

[plv]: https://github.com/phoenixframework/phoenix_live_view
[lvi]: https://github.com/phoenixframework/phoenix_live_view#installation
[sla]: https://elixir-slackin.herokuapp.com
[ba]: https://hexdocs.pm/basic_auth/readme.html
[oi]: installation.html
[do]: https://getoban.pro/docs/pro/docker.html
[gi]: https://getoban.pro/docs/pro/gigalixir.html
[he]: https://getoban.pro/docs/pro/heroku.html
