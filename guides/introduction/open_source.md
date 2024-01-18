# Open Source App Integration

Oban Web can seamlessly integrate with an open source application with minimal adjustments.
This guide outlines an alternative setup that enables external contributors to contribute to the
application without having an Oban Web license.

Thanks to [glific][gl] and [the changelog][cl] for pioneering the approach outlined in this guide.

[gl]: https://github.com/glific/glific
[cl]: https://github.com/thechangelog/changelog.com

## Installation

The first step uses an environment variable check to conditionally bypass `oban_web` installation
in select environments.

Set a module attribute in `mix.exs` to define which environments the package will install into.
The `:prod` environment is always included. When the `OBAN_LICENSE_KEY` value is set, then it also
includes `:dev`.

```elixir
# mix.exs
if System.get_env("OBAN_LICENSE_KEY") do
  @oban_envs [:dev, :prod]
else
  @oban_envs [:prod]
end
```

Add `:oban_web` to deps with an `only` condition based on the `@oban_envs` module attribute
defined above. The `only` condition restricts installing or checking for `oban_web` to the
specified environments.

```elixir
# mix.exs
{:oban_web, "~> 2.10", repo: "oban", only: @oban_envs},
```

Finally, add a `deps.get_dev` alias to ensure contributors can fetch dependencies without a
license key present. Unlocking `oban_web` and the transitive `oban_met` removes them from
`mix.lock`, which allows the `only` check to work as expected.

```elixir
# mix.exs
"deps.get_dev": ["deps.unlock oban_web oban_met", "deps.get --only dev"]
```

Now contributors without access to the license key can run `mix deps.get_dev` instead of the
standard `mix deps.get`.

## Configuration

The next step is to define a module that encompasses importing and mounting the Web dashboard. A
`__using__` macro checks for the presence of `Oban.Web.Router` at compilation time, and only
imports when it's available. When the router isn't available nothing is imported or mounted, and
the router can still safely compile.

Be sure to tailor the `scope`, `pipe_through`, and `oban_dashboard` options to your liking here.

```elixir
# oban_web.ex
defmodule MyAppWeb.ObanWeb do
  defmacro __using__(_opts) do
    if Code.ensure_loaded?(Oban.Web.Router) do
      quote do
        import Oban.Web.Router

        scope "/" do
          pipe_through [:browser]

          oban_dashboard "/oban"
        end
      end
    end
  end
end
```

Within your application's router you'll `use` the newly created `ObanWeb` module rather than
importing `Oban.Web.Router` directly:

```elixir
# router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  use MyAppWeb.ObanWeb
```

The open-source-friendly installation is complete and you're all set!
