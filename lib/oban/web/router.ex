defmodule Oban.Web.Router do
  @moduledoc """
  Provides routing for Oban.Web dashboards.
  """

  alias Oban.Web.Resolver

  @default_opts [
    oban_name: Oban,
    transport: "websocket",
    default_refresh: 1,
    resolver: Resolver
  ]

  @refresh_values [1, 2, 5, 15, -1]
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
      opts[:default_refresh],
      opts[:resolver]
    ]

    opts
    |> Keyword.put_new(:as, :oban_dashboard)
    |> Keyword.put_new(:layout, {Oban.Web.LayoutView, "app.html"})
    |> Keyword.put_new(:session, {__MODULE__, :__session__, session_args})
  end

  @doc false
  def __session__(conn, oban, transport, refresh, resolver) do
    user = resolver.resolve_user(conn)
    access = resolver.resolve_access(user)

    %{
      "oban" => oban,
      "refresh" => refresh,
      "transport" => transport,
      "user" => user,
      "access" => access
    }
  end

  defp validate_opt!({:oban_name, name}) do
    unless is_atom(name) do
      raise ArgumentError, """
      invalid :oban_name, expected a module or atom,
      got #{inspect(name)}
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

  defp validate_opt!({:default_refresh, refresh}) do
    unless refresh in @refresh_values do
      raise ArgumentError, """
      invalid :default_refresh, expected one of #{inspect(@refresh_values)},
      got #{refresh}
      """
    end
  end

  defp validate_opt!({:resolver, resolver}) do
    unless is_atom(resolver) and Code.ensure_loaded?(resolver) do
      raise ArgumentError, """
      invalid :resolver, expected a module that implements the Oban.Web.Resolver behaviour,
      got: #{inspect(resolver)}
      """
    end
  end

  defp validate_opt!(_option), do: :ok
end
