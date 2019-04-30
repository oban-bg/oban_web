defmodule ObanWeb.DashboardLive do
  use Phoenix.LiveView

  alias ObanWeb.{DashboardView, Query, Stats}

  @default_filters %{state: "executing", queue: "any"}

  def render(assigns) do
    DashboardView.render("index.html", assigns)
  end

  def mount(_session, socket) do
    if connected?(socket), do: :timer.send_interval(500, self(), :tick)

    config = Oban.config()
    filters = @default_filters

    assigns = [
      jobs: Query.jobs(config.repo, filters),
      node_counts: Stats.for_nodes(),
      queue_counts: Stats.for_queues(),
      state_counts: Stats.for_states(),
      config: config,
      filters: filters
    ]

    {:ok, assign(socket, assigns)}
  end

  def handle_info(:tick, %{assigns: assigns} = socket) do
    assigns = [
      jobs: Query.jobs(assigns.config.repo, assigns.filters),
      node_counts: Stats.for_nodes(),
      queue_counts: Stats.for_queues(),
      state_counts: Stats.for_states()
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
