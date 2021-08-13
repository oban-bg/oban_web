Application.put_env(:oban_web, Oban.Web.Endpoint,
  http: [port: 4002],
  live_view: [signing_salt: "eX7TFPY6Y/+XQ1o2pOUW3DjgAoXGTAdX"],
  secret_key_base: "jAu3udxm+8tIRDXLLKo+EupAlEvdLsnNG82O8e9nqylpBM9gP8AjUnZ4PWNttztU",
  server: false,
  render_errors: [view: Oban.Web.ErrorView],
  check_origin: false,
  url: [host: "localhost"]
)

defmodule Oban.Web.ErrorView do
  use Oban.Web, :view

  def render(_template, _assigns) do
    "Internal Server Error"
  end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule Oban.Web.Test.Router do
  use Phoenix.Router

  import Oban.Web.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/", ThisWontBeUsed, as: :this_wont_be_used do
    pipe_through :browser

    oban_dashboard("/oban")
    oban_dashboard("/oban-private", as: :oban_private_dashboard, oban_name: ObanPrivate)
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
Oban.Web.Endpoint.start_link()

ExUnit.start()
