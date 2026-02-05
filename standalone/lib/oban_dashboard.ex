defmodule ObanDashboard.Repo do
  use Ecto.Repo, otp_app: :oban_dashboard, adapter: Ecto.Adapters.Postgres
end

defmodule ObanDashboard.Resolver do
  @behaviour Oban.Web.Resolver

  @impl true
  def resolve_access(_user) do
    if Application.get_env(:oban_dashboard, :read_only, false) do
      :read_only
    else
      :all
    end
  end
end

defmodule ObanDashboard.Router do
  use Phoenix.Router, helpers: false

  import Oban.Web.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/" do
    get "/health", ObanDashboard.HealthController, :index

    pipe_through :browser

    get "/", ObanDashboard.RedirectController, :index
    oban_dashboard "/oban", resolver: ObanDashboard.Resolver
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

defmodule ObanDashboard.HealthController do
  use Phoenix.Controller, formats: [:json]

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, ~s({"status":"ok"}))
  end
end

defmodule ObanDashboard.RedirectController do
  use Phoenix.Controller, formats: [:html]

  def index(conn, _params) do
    redirect(conn, to: "/oban")
  end
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
