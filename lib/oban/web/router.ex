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

    validate_oban_name!(oban_name)
    validate_transport!(transport)

    opts
    |> Keyword.put_new(:as, :oban_dashboard)
    |> Keyword.put_new(:session, {__MODULE__, :__session__, [oban_name, transport]})
    |> Keyword.put_new(:layout, {Oban.Web.LayoutView, "app.html"})
  end

  @doc false
  def __session__(_conn, oban, transport) do
    %{"oban" => oban, "transport" => transport}
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
end
