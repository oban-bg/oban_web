defmodule ObanDash.Repo do
  use Ecto.Repo, otp_app: :oban_dash, adapter: Ecto.Adapters.Postgres
end

defmodule ObanDash.BasicAuth do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    user = Application.get_env(:oban_dash, :basic_auth_user)
    pass = Application.get_env(:oban_dash, :basic_auth_pass)

    if user && pass do
      authenticate(conn, user, pass)
    else
      conn
    end
  end

  defp authenticate(conn, user, pass) do
    with ["Basic " <> encoded] <- get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.decode64(encoded),
         ^decoded <- "#{user}:#{pass}" do
      conn
    else
      _ ->
        conn
        |> put_resp_header("www-authenticate", ~s(Basic realm="Oban Dashboard"))
        |> send_resp(401, "Unauthorized")
        |> halt()
    end
  end
end

defmodule ObanDash.Resolver do
  @behaviour Oban.Web.Resolver

  @impl true
  def resolve_access(_user) do
    if Application.get_env(:oban_dash, :read_only, false) do
      :read_only
    else
      :all
    end
  end
end

defmodule ObanDash.Router do
  use Phoenix.Router, helpers: false

  import Oban.Web.Router

  pipeline :browser do
    plug :fetch_session
    plug ObanDash.BasicAuth
  end

  scope "/" do
    get "/health", ObanDash.HealthController, :index

    pipe_through :browser

    get "/", ObanDash.RedirectController, :index
    oban_dashboard "/oban", resolver: ObanDash.Resolver
  end
end

defmodule ObanDash.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_dash

  socket "/live", Phoenix.LiveView.Socket

  plug Plug.Session,
    store: :cookie,
    key: "_oban_dash_key",
    signing_salt: "oban_dashboard"

  plug ObanDash.Router
end

defmodule ObanDash.HealthController do
  use Phoenix.Controller, formats: [:json]

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, ~s({"status":"ok"}))
  end
end

defmodule ObanDash.RedirectController do
  use Phoenix.Controller, formats: [:html]

  def index(conn, _params) do
    redirect(conn, to: "/oban")
  end
end

defmodule ObanDash.ErrorHTML do
  use Phoenix.Component

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule ObanDash.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ObanDash.Repo,
      {Oban, oban_opts()},
      ObanDash.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ObanDash.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp oban_opts do
    [
      engine: engine(),
      notifier: Oban.Notifiers.Postgres,
      repo: ObanDash.Repo,
      prefix: Application.fetch_env!(:oban_dash, :oban_prefix),
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
