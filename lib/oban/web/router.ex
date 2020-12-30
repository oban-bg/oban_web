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

  @default_opts [
    oban_name: Oban,
    transport: "websocket",
    default_refresh: 1,
    resolve_user: &__MODULE__.__resolve_user__/1
  ]

  @refresh_values [1, 2, 5, 15, -1]
  @transport_values ~w(longpoll websocket)

  @doc false
  def __options__(opts) do
    opts = Keyword.merge(@default_opts, opts)

    Enum.each(opts, &validate_opt!/1)

    session_args = [
      opts[:oban_name],
      opts[:transport],
      opts[:default_refresh],
      opts[:resolve_user]
    ]

    opts
    |> Keyword.put_new(:as, :oban_dashboard)
    |> Keyword.put_new(:session, {__MODULE__, :__session__, session_args})
    |> Keyword.put_new(:layout, {Oban.Web.LayoutView, "app.html"})
  end

  @doc false
  def __session__(conn, oban, transport, refresh, resolve_user) do
    %{
      "oban" => oban,
      "refresh" => refresh,
      "transport" => transport,
      "user" => resolve_user.(conn)
    }
  end

  @doc false
  def __resolve_user__(_conn), do: nil

  defp validate_opt!({:oban_name, name}) do
    unless is_atom(name) do
      raise ArgumentError, """
      invalid :oban_name, expected a module or atom but got #{inspect(name)}
      """
    end
  end

  defp validate_opt!({:transport, transport}) do
    unless transport in @transport_values do
      raise ArgumentError, """
      invalid :transport, expected either "longpoll" or "websocket", got #{inspect(transport)}
      """
    end
  end

  defp validate_opt!({:default_refresh, refresh}) do
    unless refresh in @refresh_values do
      raise ArgumentError, """
      invalid :default_refresh, expected one of #{inspect(@refresh_values)}, got #{refresh}
      """
    end
  end

  defp validate_opt!({:resolve_user, fun}) do
    unless is_function(fun, 1) do
      raise ArgumentError, """
      invalid :resolve_user, expected a function with an arity of 1, got: #{inspect(fun)}
      """
    end
  end

  defp validate_opt!(_option), do: :ok
end
