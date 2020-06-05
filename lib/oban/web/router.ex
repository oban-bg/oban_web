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
    opts
    |> Keyword.put_new(:as, :oban_dashboard)
    |> Keyword.put_new(:layout, {Oban.Web.LayoutView, "app.html"})
  end
end
