defmodule ObanWeb.DashboardController do
  use ObanWeb, :controller

  import Ecto.Query, only: [where: 2]

  alias Oban.Config

  def index(conn, _params) do
    %Config{repo: repo} = Oban.config()

    executing =
      Oban.Job
      |> where(state: "executing")
      |> repo.all()

    render(conn, "index.html", jobs: executing)
  end
end
