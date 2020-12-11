defmodule Oban.Web.Router do
  @moduledoc """
  Provides routing for Oban.Web dashboards.
  """

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
    oban_name = Keyword.get(opts, :oban_name, Oban)
    transport = Keyword.get(opts, :transport, "websocket")
    refresh = Keyword.get(opts, :default_refresh, 1)

    validate_oban_name!(oban_name)
    validate_transport!(transport)
    validate_refresh!(refresh)

    session_args = [oban_name, transport, refresh]

    opts
    |> Keyword.put_new(:as, :oban_dashboard)
    |> Keyword.put_new(:session, {__MODULE__, :__session__, session_args})
    |> Keyword.put_new(:layout, {Oban.Web.LayoutView, "app.html"})
  end

  @doc false
  def __session__(_conn, oban, transport, refresh) do
    %{"oban" => oban, "refresh" => refresh, "transport" => transport}
  end

  defp validate_oban_name!(name) do
    unless is_atom(name) do
      raise ArgumentError, """
      invalid :oban_name, expected a module or atom but got #{inspect(name)}
      """
    end
  end

  defp validate_transport!(tran) do
    unless tran in ~w(longpoll websocket) do
      raise ArgumentError, """
      invalid :transport, expected either "longpoll" or "websocket", got #{inspect(tran)}
      """
    end
  end

  @refresh_values [1, 2, 5, 15, -1]
  defp validate_refresh!(refresh) do
    unless refresh in @refresh_values do
      raise ArgumentError, """
      invalid :default_refresh, expected one of #{inspect(@refresh_values)}, got #{refresh}
      """
    end
  end
end
