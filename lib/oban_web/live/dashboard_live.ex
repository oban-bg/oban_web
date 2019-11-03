defmodule ObanWeb.DashboardLive do
  @moduledoc false

  use Phoenix.LiveView

  alias Oban.Job
  alias ObanWeb.{DashboardView, Query, Stats}

  @tick_timing 500
  @flash_timing 5_000
  @default_flash %{show: false, mode: :success, message: ""}
  @default_filters %{
    node: "any",
    queue: "any",
    state: "executing",
    terms: nil,
    worker: "any"
  }

  def render(assigns) do
    DashboardView.render("index.html", assigns)
  end

  def mount(_session, socket) do
    if connected?(socket), do: Process.send_after(self(), :tick, @tick_timing)

    config = Oban.config()
    filters = @default_filters

    assigns = [
      config: config,
      filters: filters,
      flash: @default_flash,
      jobs: Query.jobs(config.repo, filters),
      node_stats: Stats.for_nodes(),
      queue_stats: Stats.for_queues(),
      state_stats: Stats.for_states()
    ]

    {:ok, assign(socket, assigns)}
  end

  def handle_info(:tick, %{assigns: assigns} = socket) do
    assigns = [
      jobs: Query.jobs(assigns.config.repo, assigns.filters),
      node_stats: Stats.for_nodes(),
      queue_stats: Stats.for_queues(),
      state_stats: Stats.for_states()
    ]

    Process.send_after(self(), :tick, @tick_timing)

    {:noreply, assign(socket, assigns)}
  end

  def handle_info(:clear_flash, %{assigns: assigns} = socket) do
    flash = Map.put(assigns.flash, :show, false)

    {:noreply, assign(socket, flash: flash)}
  end

  def handle_event("change_node", %{"node" => node}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :node, node)
    jobs = Query.jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_queue", %{"queue" => queue}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :queue, queue)
    jobs = Query.jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_state", %{"state" => state}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :state, state)
    jobs = Query.jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_terms", %{"terms" => terms}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :terms, terms)
    jobs = Query.jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_worker", %{"worker" => worker}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :worker, worker)
    jobs = Query.jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("clear_filter", %{"type" => type}, %{assigns: assigns} = socket) do
    type = String.to_existing_atom(type)
    default = Map.get(@default_filters, type)
    filters = Map.put(assigns.filters, type, default)
    jobs = Query.jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("delete_job", %{"id" => job_id}, %{assigns: assigns} = socket) do
    {:ok, _schema} = assigns.config.repo.delete(%Job{args: %{}, id: String.to_integer(job_id)})

    flash = %{show: true, mode: :alert, message: "Job deleted."}

    Process.send_after(self(), :clear_flash, @flash_timing)

    {:noreply, assign(socket, flash: flash)}
  end

  def handle_event("kill_job", %{"id" => job_id}, socket) do
    :ok =
      job_id
      |> String.to_integer()
      |> Oban.kill_job()

    flash = %{show: true, mode: :alert, message: "Job canceled and discarded."}

    Process.send_after(self(), :clear_flash, @flash_timing)

    {:noreply, assign(socket, flash: flash)}
  end

  def handle_event("blitz_close", _value, socket) do
    handle_info(:clear_flash, socket)
  end
end
