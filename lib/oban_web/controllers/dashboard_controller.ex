defmodule ObanWeb.DashboardController do
  use ObanWeb, :controller

  import Phoenix.LiveView.Controller, only: [live_render: 3]

  def index(conn, _params) do
    live_render(conn, ObanWeb.DashboardLive, session: %{})
  end
end
