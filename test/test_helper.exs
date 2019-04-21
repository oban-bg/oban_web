Logger.configure(level: :info)

ExUnit.start()

ObanWeb.Repo.start_link()
ObanWeb.Endpoint.start_link()
