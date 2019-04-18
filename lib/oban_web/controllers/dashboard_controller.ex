defmodule ObanWeb.DashboardController do
  use ObanWeb, :controller

  import Ecto.Query

  alias Oban.Config
  alias ObanWeb.Query

  def index(conn, _params) do
    %Config{queues: queues, repo: repo} = Oban.config()

    render(conn,
      "index.html",
      jobs: Query.jobs(repo),
      queues: Query.queue_counts(queues, repo),
      states: Query.state_counts(repo)
    )
  end
end
