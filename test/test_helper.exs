Application.put_env(:oban_web, ObanWeb.Endpoint,
  http: [port: 4002],
  live_view: [signing_salt: "eX7TFPY6Y/+XQ1o2pOUW3DjgAoXGTAdX"],
  secret_key_base: "jAu3udxm+8tIRDXLLKo+EupAlEvdLsnNG82O8e9nqylpBM9gP8AjUnZ4PWNttztU",
  server: false,
  render_errors: [view: ObanWeb.ErrorView],
  check_origin: false,
  url: [host: "localhost"]
)

defmodule ObanWeb.ErrorView do
  use ObanWeb.Web, :view

  def render(_template, _assigns) do
    "Internal Server Error"
  end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule ObanWeb.Test.Router do
  use Phoenix.Router

  import ObanWeb.Router

  pipeline :browser do
    plug :fetch_session
  end

  scope "/", ThisWontBeUsed, as: :this_wont_be_used do
    pipe_through :browser

    oban_dashboard("/oban")
  end
end

defmodule ObanWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_web

  socket "/live", Phoenix.LiveView.Socket

  plug Plug.Session,
    store: :cookie,
    key: "_oban_web_key",
    signing_salt: "cuxdCB1L"

  plug ObanWeb.Test.Router
end

ObanWeb.Repo.start_link()
ObanWeb.Endpoint.start_link()
Oban.start_link(repo: ObanWeb.Repo, queues: [default: 1])

ExUnit.start()
