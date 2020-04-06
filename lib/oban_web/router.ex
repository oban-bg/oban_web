defmodule ObanWeb.Router do
  @moduledoc """
  Provides routing for ObanWeb dashboards.
  """

  @doc """
  Defines an oban dashboard route.

  It requires a path where to mount the dashboard at and allows options to customize routing.

  ## Examples

  Mount an `oban` dashboard at the path "/oban":

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        import ObanWeb.Router

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

        opts = ObanWeb.Router.__options__(opts)

        live "/", ObanWeb.DashboardLive, :index, opts
      end
    end
  end

  @doc false
  def __options__(opts) do
    opts
    |> Keyword.put_new(:as, :oban_dashboard)
    |> Keyword.put_new(:layout, {ObanWeb.LayoutView, "app.html"})
  end
end
