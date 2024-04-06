defmodule Oban.Web.Router do
  @moduledoc """
  Provides mount points for the Web dashboard with customization.

  ### Customizing with a Resolver Callback Module

  Implementing a `Oban.Web.Resolver` callback module allows you to customize the dashboard
  per-user, i.e. setting access controls or the default refresh rate.

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

  See the `Oban.Web.Resolver` docs for more details.

  ### Running Multiple Dashboards

  Applications that run multiple Oban instances can mount a dashboard for each instance. Set the
  mounted dashboard's `:oban_name` to match the corresponding supervision tree's name. For
  example, given two configured Oban instances, `Oban` and `MyAdmin.Oban`:

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

  Note that the default name is `Oban`, setting `oban_name: Oban` in the example above was purely
  for demonstration purposes.

  ### On Mount Hooks

  You can provide a list of hooks to attach to the dashboard's mount lifecycle. Additional hooks
  are prepended before [Oban Web's own Authentication](Oban.Web.Resolver). For example, to run a
  user-fetching hook and an activation checking hook before mount:

  ```elixir
  scope "/" do
    pipe_through :browser

    oban_dashboard "/oban", on_mount: [MyApp.UserHook, MyApp.ActivatedHook]
  end
  ```

  ### Customizing the Socket Connection

  Applications that use a live socket other than "/live" can override the default socket path in
  the router. For example, if your live socket is hosted at `/oban_live`:

  ```elixir
  socket "/oban_live", Phoenix.LiveView.Socket

  scope "/" do
    pipe_through :browser

    oban_dashboard "/oban", socket_path: "/oban_live"
  end
  ```

  If your application is hosted in an environment that doesn't support websockets you can use
  longpolling as an alternate transport. To start, make sure that your live socket is configured
  for longpolling:

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

  To secure the dashboard, or comply with an existing CSP within your application, you can specify
  nonce keys for images, scripts and styles.

  You'll configure the CSP nonce assign key in your router, where the dashboard is mounted. For
  example, to use a single nonce for all three asset types:

  ```elixir
  oban_dashboard("/oban", csp_nonce_assign_key: :my_csp_nonce)
  ```

  That instructs the dashboard to extract a generated nonce from the `assigns` map on the plug
  connection, at the `:my_csp_nonce` key.

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
  """

  alias Oban.Web.Resolver

  @default_opts [
    oban_name: Oban,
    resolver: Resolver,
    socket_path: "/live",
    transport: "websocket"
  ]

  @transport_values ~w(longpoll websocket)

  @doc """
  Defines an oban dashboard route.

  It requires a path where to mount the dashboard at and allows options to customize routing.

  ## Options

  * `:oban_name` — name of the Oban instance the dashboard will use for configuration and
    notifications, defaults to `Oban`

  * `:resolver` — an `Oban.Web.Resolver` implementation used to customize the dashboard's
    functionality.

  * `:socket_path` — a phoenix socket path for live communication, defaults to `"/live"`.

  * `:transport` — a phoenix socket transport, either `"websocket"` or `"longpoll"`, defaults to
    `"websocket"`.

  * `:csp_nonce_assign_key` — CSP (Content Security Policy) keys used to authenticate image,
    style, and script assets by pulling a generated nonce out of the connection's `assigns` map. May
    be `nil`, a single atom, or a map of atoms. Defaults to `nil`.

  ## Examples

  Mount an `oban` dashboard at the path "/oban":

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        import Oban.Web.Router

        scope "/", MyAppWeb do
          pipe_through [:browser]

          oban_dashboard "/oban"
        end
      end
  """
  defmacro oban_dashboard(path, opts \\ []) do
    opts =
      if Macro.quoted_literal?(opts) do
        Macro.prewalk(opts, &expand_alias(&1, __CALLER__))
      else
        opts
      end

    quote bind_quoted: binding() do
      prefix = Phoenix.Router.scoped_path(__MODULE__, path)

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        {session_name, session_opts, route_opts} = Oban.Web.Router.__options__(prefix, opts)

        live_session session_name, session_opts do
          live "/", Oban.Web.DashboardLive, :home, route_opts
          live "/:page", Oban.Web.DashboardLive, :index, route_opts
          live "/:page/:id", Oban.Web.DashboardLive, :show, route_opts
        end
      end
    end
  end

  defp expand_alias({:__aliases__, _, _} = alias, env) do
    Macro.expand(alias, %{env | function: {:oban_dashboard, 2}})
  end

  defp expand_alias(other, _env), do: other

  @doc false
  def __options__(prefix, opts) do
    opts = Keyword.merge(@default_opts, opts)

    Enum.each(opts, &validate_opt!/1)

    on_mount = Keyword.get(opts, :on_mount, []) ++ [Oban.Web.Authentication]

    session_args = [
      prefix,
      opts[:oban_name],
      opts[:resolver],
      opts[:socket_path],
      opts[:transport],
      opts[:csp_nonce_assign_key]
    ]

    session_opts = [
      on_mount: on_mount,
      session: {__MODULE__, :__session__, session_args},
      root_layout: {Oban.Web.Layouts, :root}
    ]

    session_name = Keyword.get(opts, :as, :oban_dashboard)

    {session_name, session_opts, as: session_name}
  end

  @doc false
  def __session__(conn, prefix, oban, resolver, live_path, live_transport, csp_key) do
    user = resolve_with_fallback(resolver, :resolve_user, [conn])

    csp_keys = expand_csp_nonce_keys(csp_key)

    %{
      "prefix" => prefix,
      "oban" => oban,
      "user" => user,
      "resolver" => resolver,
      "access" => resolve_with_fallback(resolver, :resolve_access, [user]),
      "refresh" => resolve_with_fallback(resolver, :resolve_refresh, [user]),
      "live_path" => live_path,
      "live_transport" => live_transport,
      "csp_nonces" => %{
        img: conn.assigns[csp_keys[:img]],
        style: conn.assigns[csp_keys[:style]],
        script: conn.assigns[csp_keys[:script]]
      }
    }
  end

  defp expand_csp_nonce_keys(nil), do: %{img: nil, style: nil, script: nil}
  defp expand_csp_nonce_keys(key) when is_atom(key), do: %{img: key, style: key, script: key}
  defp expand_csp_nonce_keys(map) when is_map(map), do: map

  defp resolve_with_fallback(resolver, function, args) do
    resolver = if function_exported?(resolver, function, 1), do: resolver, else: Resolver

    apply(resolver, function, args)
  end

  defp validate_opt!({:csp_nonce_assign_key, key}) do
    unless is_nil(key) or is_atom(key) or is_map(key) do
      raise ArgumentError, """
      invalid :csp_nonce_assign_key, expected nil, an atom or a map with atom keys,
      got #{inspect(key)}
      """
    end
  end

  defp validate_opt!({:oban_name, name}) do
    unless is_atom(name) do
      raise ArgumentError, """
      invalid :oban_name, expected a module or atom,
      got #{inspect(name)}
      """
    end
  end

  defp validate_opt!({:resolver, resolver}) do
    unless is_atom(resolver) and not is_nil(resolver) do
      raise ArgumentError, """
      invalid :resolver, expected a module that implements the Oban.Web.Resolver behaviour,
      got: #{inspect(resolver)}
      """
    end
  end

  defp validate_opt!({:socket_path, path}) do
    unless is_binary(path) and byte_size(path) > 0 do
      raise ArgumentError, """
      invalid :socket_path, expected a binary URL, got: #{inspect(path)}
      """
    end
  end

  defp validate_opt!({:transport, transport}) do
    unless transport in @transport_values do
      raise ArgumentError, """
      invalid :transport, expected one of #{inspect(@transport_values)},
      got #{inspect(transport)}
      """
    end
  end

  defp validate_opt!(_option), do: :ok
end
