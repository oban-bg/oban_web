Application.ensure_all_started(:postgrex)

Application.put_env(:oban_met, :auto_start, false)
Application.put_env(:oban_web, :cache, false)

Application.put_env(:oban_web, Oban.Web.Endpoint,
  check_origin: false,
  http: [port: 4002],
  live_view: [signing_salt: "eX7TFPY6Y/+XQ1o2pOUW3DjgAoXGTAdX"],
  render_errors: [formats: [html: Oban.Web.ErrorHTML], layout: false],
  secret_key_base: "jAu3udxm+8tIRDXLLKo+EupAlEvdLsnNG82O8e9nqylpBM9gP8AjUnZ4PWNttztU",
  server: false,
  url: [host: "localhost"]
)

defmodule Oban.Web.ErrorHTML do
  use Phoenix.Component

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule PrivateResolver do
  @behaviour Oban.Web.Resolver

  @impl Oban.Web.Resolver
  def resolve_instances(_user), do: [ObanPrivate]
end

defmodule LimitedResolver do
  @behaviour Oban.Web.Resolver

  @impl Oban.Web.Resolver
  def resolve_user(_conn), do: %{id: 0}

  @impl Oban.Web.Resolver
  def resolve_access(%{id: 0}), do: {:forbidden, "/"}
  def resolve_access(_user), do: :all
end

defmodule Oban.Web.Test.Router do
  use Phoenix.Router

  import Oban.Web.Router

  pipeline :browser do
    plug :fetch_session
    plug :fetch_flash
  end

  scope "/", ThisWontBeUsed, as: :this_wont_be_used do
    pipe_through :browser

    oban_dashboard "/oban"
    oban_dashboard "/oban-limited", as: :oban_limited, resolver: LimitedResolver

    oban_dashboard "/oban-private",
      as: :oban_private,
      oban_name: ObanPrivate,
      resolver: PrivateResolver
  end
end

defmodule Oban.Web.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_web

  socket "/live", Phoenix.LiveView.Socket

  plug Plug.Session,
    store: :cookie,
    key: "_oban_web_key",
    signing_salt: "cuxdCB1L"

  plug Oban.Web.Test.Router
end

Oban.Web.Repo.start_link()
Oban.Web.MyXQLRepo.start_link()
Oban.Web.SQLiteRepo.start_link()
Oban.Web.Endpoint.start_link()

Ecto.Adapters.SQL.Sandbox.mode(Oban.Web.MyXQLRepo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Oban.Web.Repo, :manual)

ExUnit.start(assert_receive_timeout: 500, refute_receive_timeout: 50, exclude: [:skip])
