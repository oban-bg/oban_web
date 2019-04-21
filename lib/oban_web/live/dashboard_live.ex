defmodule ObanWeb.DashboardLive do
  use Phoenix.LiveView

  alias Oban.Config
  alias ObanWeb.{DashboardView, Query}

  def render(assigns) do
    DashboardView.render("index.html", assigns)
  end

  def mount(_session, socket) do
    if connected?(socket), do: :timer.send_interval(500, self(), :tick)

    %Config{queues: queues, repo: repo} = Oban.config()

    assigns = [
      jobs: Query.jobs(repo),
      queues: Query.queue_counts(queues, repo),
      states: Query.state_counts(repo)
    ]

    {:ok, assign(socket, assigns)}
  end

  def handle_info(:tick, socket) do
    %Config{queues: queues, repo: repo} = Oban.config()

    assigns = [
      jobs: Query.jobs(repo),
      queues: Query.queue_counts(queues, repo),
      states: Query.state_counts(repo)
    ]

    # Only change the jobs initially
    {:noreply, assign(socket, assigns)}
  end

  def handle_event("change_state", state, socket) do
    %Config{repo: repo} = Oban.config()

    {:noreply, assign(socket, jobs: Query.jobs(repo, state: state))}
  end
end
