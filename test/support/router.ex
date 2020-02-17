defmodule ObanWeb.Router do
  use Phoenix.Router

  import Phoenix.Controller
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
  end

  scope "/" do
    pipe_through :browser

    live "/oban", ObanWeb.DashboardLive
  end
end
