defmodule ObanWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_web

  @session_options store: :cookie,
                   key: "_oban_web_key",
                   signing_salt: "cuxdCB1L"

  socket "/live", Phoenix.LiveView.Socket

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.Session, @session_options

  plug ObanWeb.Support.Router
end
