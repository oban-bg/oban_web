Logger.configure(level: :info)

ExUnit.start()

ObanWeb.Repo.start_link()
ObanWeb.Endpoint.start_link()
Oban.start_link(repo: ObanWeb.Repo, queues: [default: 1])
