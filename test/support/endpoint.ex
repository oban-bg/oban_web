defmodule ObanWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :oban_web

  socket "/live", Phoenix.LiveView.Socket

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug ObanWeb.Router
end
