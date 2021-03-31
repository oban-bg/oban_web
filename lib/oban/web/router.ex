defmodule Oban.Web.Router do
  @moduledoc """
  Provides routing for Oban.Web dashboards.
  """

  alias Oban.Web.Resolver

  @default_opts [
    oban_name: Oban,
    transport: "websocket",
    resolver: Resolver
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
        import Phoenix.LiveView.Router, only: [live: 4]

        opts = Oban.Web.Router.__options__(opts)

        live "/", Oban.Web.DashboardLive, :index, opts
      end
    end
  end

  @doc false
  def __options__(opts) do
    opts = Keyword.merge(@default_opts, opts)

    Enum.each(opts, &validate_opt!/1)

    session_args = [
      opts[:oban_name],
      opts[:transport],
      opts[:resolver],
      opts[:csp_nonce_assign_key]
    ]

    opts
    |> Keyword.put_new(:as, :oban_dashboard)
    |> Keyword.put_new(:layout, {Oban.Web.LayoutView, "app.html"})
    |> Keyword.put_new(:session, {__MODULE__, :__session__, session_args})
  end

  @doc false
  def __session__(conn, oban, transport, resolver, csp_nonce_assign_key) do
    user = resolve_with_fallback(resolver, :resolve_user, [conn])

    csp_keys = expand_csp_nonce_keys(csp_nonce_assign_key)

    %{
      "oban" => oban,
      "transport" => transport,
      "user" => user,
      "access" => resolve_with_fallback(resolver, :resolve_access, [user]),
      "refresh" => resolve_with_fallback(resolver, :resolve_refresh, [user]),
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
    unless is_atom(resolver) and Code.ensure_loaded?(resolver) do
      raise ArgumentError, """
      invalid :resolver, expected a module that implements the Oban.Web.Resolver behaviour,
      got: #{inspect(resolver)}
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
