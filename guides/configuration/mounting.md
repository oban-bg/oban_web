# Mounting Dashboards

### Running Multiple Dashboards

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

  oban_dashboard "/oban", oban_name: Oban, as: :oban_dashboard
  oban_dashboard "/admin/oban", oban_name: MyAdmin.Oban, as: :oban_admin_dashboard
end
```

Note that the default name is `Oban`, setting `oban_name: Oban` in the example
above was purely for demonstration purposes.

### Customizing the Socket Connection

Applications that use a live socket other than "/live" can override the default
socket path in the router. For example, if your live socket is hosted at
`/oban_live`:

```elixir
socket "/oban_live", Phoenix.LiveView.Socket

scope "/" do
  pipe_through :browser

  oban_dashboard "/oban", socket_path: "/oban_live"
end
```

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

### Content Security Policy

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

### Customizing with a Resolver Callback Module

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

[cus]: web_customizing.html
