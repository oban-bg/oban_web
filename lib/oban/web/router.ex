defmodule Oban.Web.Router do
  @moduledoc false

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
    quote bind_quoted: binding() do
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        {session_name, session_opts, route_opts} = Oban.Web.Router.__options__(opts)

        live_session session_name, session_opts do
          live "/", Oban.Web.DashboardLive, :home, route_opts
          live "/:page", Oban.Web.DashboardLive, :index, route_opts
          live "/:page/:id", Oban.Web.DashboardLive, :show, route_opts
        end
      end
    end
  end

  @doc false
  def __options__(opts) do
    opts = Keyword.merge(@default_opts, opts)

    Enum.each(opts, &validate_opt!/1)

    session_name = Keyword.get(opts, :as, :oban_dashboard)

    path_helper =
      [session_name, :path]
      |> Enum.join("_")
      |> String.to_atom()

    session_args = [
      path_helper,
      opts[:oban_name],
      opts[:resolver],
      opts[:socket_path],
      opts[:transport],
      opts[:csp_nonce_assign_key]
    ]

    session_opts = [
      session: {__MODULE__, :__session__, session_args},
      root_layout: {Oban.Web.LayoutView, :app}
    ]

    {session_name, session_opts, as: session_name}
  end

  @doc false
  def __session__(conn, path_helper, oban, resolver, live_path, live_transport, csp_key) do
    user = resolve_with_fallback(resolver, :resolve_user, [conn])

    csp_keys = expand_csp_nonce_keys(csp_key)

    %{
      "path_helper" => path_helper,
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

  defp validate_opt!({:default_refresh, _refresh}) do
    IO.warn("The :default_refresh option is deprecated, use a Resolver callback module instead")
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
