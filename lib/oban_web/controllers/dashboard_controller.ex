defmodule ObanWeb.DashboardController do
  use ObanWeb, :controller

  import Ecto.Query, only: [where: 2]

  # TODO: Dynamically fetch the repo

  def index(conn, _params) do
    executing =
      Oban.Job
      |> where(state: "executing")
      |> Lysmore.Repo.all()

    render(conn, "index.html", jobs: executing)
  end
end
