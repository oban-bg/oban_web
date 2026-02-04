defmodule ObanDashboard.Repo do
  use Ecto.Repo, otp_app: :oban_dashboard, adapter: Ecto.Adapters.Postgres
end

defmodule ObanDashboard.Router do
  use Phoenix.Router, helpers: false

  import Oban.Web.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/" do
    pipe_through :browser

    oban_dashboard "/oban"
  end
end

defmodule ObanDashboard.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_dashboard

  socket "/live", Phoenix.LiveView.Socket

  plug Plug.Session,
    store: :cookie,
    key: "_oban_dashboard_key",
    signing_salt: "oban_dashboard"

  plug ObanDashboard.Router
end

defmodule ObanDashboard.ErrorHTML do
  use Phoenix.Component

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule ObanDashboard.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ObanDashboard.Repo,
      {Oban, oban_opts()},
      ObanDashboard.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ObanDashboard.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp oban_opts do
    [
      engine: engine(),
      notifier: Oban.Notifiers.PG,
      repo: ObanDashboard.Repo,
      prefix: Application.fetch_env!(:oban_dashboard, :oban_prefix),
      plugins: false,
      queues: false
    ]
  end

  defp engine do
    if Code.ensure_loaded?(Oban.Pro.Engines.Smart) do
      Oban.Pro.Engines.Smart
    else
      Oban.Engines.Basic
    end
  end
end
