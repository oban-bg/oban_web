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

defmodule ObanDash.Cluster do
  @moduledoc false

  # Connects to every node registered with EPMD on the configured hosts, named `alive@host`. That
  # matches how oban-py's Erlang notifier discovers nodes, and is enough to join an Elixir cluster
  # because distribution meshes transitively from there.

  use GenServer

  @interval :timer.seconds(5)

  def start_link(hosts) do
    GenServer.start_link(__MODULE__, hosts, name: __MODULE__)
  end

  @impl GenServer
  def init(hosts) do
    send(self(), :connect)

    {:ok, hosts}
  end

  @impl GenServer
  def handle_info(:connect, hosts) do
    connected = [Node.self() | Node.list()]

    for host <- hosts, peer <- epmd_nodes(host), peer not in connected do
      Node.connect(peer)
    end

    Process.send_after(self(), :connect, @interval)

    {:noreply, hosts}
  end

  defp epmd_nodes(host) do
    case :erl_epmd.names(String.to_charlist(host)) do
      {:ok, names} -> for {name, _port} <- names, do: :"#{name}@#{host}"
      _error -> []
    end
  end
end

defmodule ObanDash.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children =
      [ObanDash.Repo] ++
        cluster_child() ++
        [{Oban, oban_opts()}, ObanDash.Endpoint]

    opts = [strategy: :one_for_one, name: ObanDash.Supervisor]

    Supervisor.start_link(children, opts)
  end

  defp cluster_child do
    case Application.get_env(:oban_dash, :cluster_hosts, []) do
      [] -> []
      hosts -> [{ObanDash.Cluster, hosts}]
    end
  end

  defp oban_opts do
    [
      engine: engine(),
      notifier: notifier(),
      repo: ObanDash.Repo,
      prefix: Application.fetch_env!(:oban_dash, :oban_prefix),
      plugins: false,
      queues: false
    ]
  end

  defp notifier do
    case Application.get_env(:oban_dash, :oban_notifier, "postgres") do
      "postgres" ->
        Oban.Notifiers.Postgres

      "pg" ->
        Oban.Notifiers.PG

      other ->
        raise ArgumentError, "expected OBAN_NOTIFIER to be postgres or pg, got: #{inspect(other)}"
    end
  end

  defp engine do
    cond do
      Code.ensure_loaded?(Oban.Pro.Engine) -> Oban.Pro.Engine
      Code.ensure_loaded?(Oban.Pro.Engines.Smart) -> Oban.Pro.Engines.Smart
      true -> Oban.Engines.Basic
    end
  end
end
