defmodule ObanWeb.DashboardLive do
  use Phoenix.LiveView

  alias Oban.Config
  alias ObanWeb.{DashboardView, Query}

  @default_filters %{state: "executing", queue: "any"}

  def render(assigns) do
    DashboardView.render("index.html", assigns)
  end

  def mount(_session, socket) do
    if connected?(socket), do: :timer.send_interval(500, self(), :tick)

    %Config{queues: queues, repo: repo} = Oban.config()

    assigns = [
      jobs: Query.jobs(repo, @default_filters),
      node_counts: [],
      queue_counts: Query.queue_counts(queues, repo),
      state_counts: Query.state_counts(repo),
      config: %{
        queues: queues,
        repo: repo
      },
      filters: @default_filters
    ]

    {:ok, assign(socket, assigns)}
  end

  def handle_info(:tick, %{assigns: assigns} = socket) do
    %{queues: queues, repo: repo} = assigns.config

    assigns = [
      jobs: Query.jobs(repo, assigns.filters),
      queue_counts: Query.queue_counts(queues, repo),
      state_counts: Query.state_counts(repo)
    ]

    {:noreply, assign(socket, assigns)}
  end

  def handle_event("change_queue", queue, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :queue, queue)
    jobs = Query.jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_state", state, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :state, state)
    jobs = Query.jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end
end
