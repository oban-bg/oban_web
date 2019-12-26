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

  # When a client reconnects it may render the dashboard before the assigns are set by `mount`.
  @render_defaults %{
    filters: @default_filters,
    flash: @default_flash,
    jobs: [],
    node_stats: [],
    queue_stats: [],
    state_stats: []
  }

  @impl Phoenix.LiveView
  def render(assigns) do
    DashboardView.render("index.html", with_render_defaults(assigns))
  end

  @impl Phoenix.LiveView
  def mount(_session, socket) do
    if connected?(socket), do: Process.send_after(self(), :tick, @tick_timing)

    config = Oban.config()

    assigns = %{
      config: config,
      filters: @default_filters,
      flash: @default_flash,
      job: nil,
      jobs: Query.get_jobs(config.repo, @default_filters),
      node_stats: Stats.for_nodes(),
      queue_stats: Stats.for_queues(),
      state_stats: Stats.for_states()
    }

    {:ok, assign(socket, with_render_defaults(assigns))}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, %{assigns: assigns} = socket) do
    case params["jid"] do
      jid when is_binary(jid) ->
        job = assigns.config.repo.get(Job, jid)

        {:noreply, assign(socket, job: job)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(:tick, %{assigns: assigns} = socket) do
    assigns = [
      jobs: Query.get_jobs(assigns.config.repo, assigns.filters),
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

  def handle_info(:close_modal, socket) do
    {:noreply, assign(socket, job: nil)}
  end

  @impl Phoenix.LiveView
  def handle_event("blitz_close", _value, socket) do
    handle_info(:clear_flash, socket)
  end

  def handle_event("change_node", %{"node" => node}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :node, node)
    jobs = Query.get_jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_queue", %{"queue" => queue}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :queue, queue)
    jobs = Query.get_jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_state", %{"state" => state}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :state, state)
    jobs = Query.get_jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_terms", %{"terms" => terms}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :terms, terms)
    jobs = Query.get_jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_worker", %{"worker" => worker}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :worker, worker)
    jobs = Query.get_jobs(assigns.config.repo, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("clear_filter", %{"type" => type}, %{assigns: assigns} = socket) do
    type = String.to_existing_atom(type)
    default = Map.get(@default_filters, type)
    filters = Map.put(assigns.filters, type, default)
    jobs = Query.get_jobs(assigns.config.repo, filters)

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

  def handle_event("open_modal", %{"id" => job_id}, %{assigns: assigns} = socket) do
    {:ok, job} = Query.fetch_job(assigns.config.repo, job_id)

    {:noreply, assign(socket, job: job)}
  end

  defp with_render_defaults(assigns) do
    Map.merge(@render_defaults, assigns)
  end
end
