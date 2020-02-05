defmodule ObanWeb.DashboardLive do
  @moduledoc false

  use Phoenix.LiveView

  alias Oban.Job
  alias ObanWeb.{Config, DashboardView, Query, Stats}

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
    job: nil,
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
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :tick, @tick_timing)

    config = Config.get()

    assigns = %{
      config: config,
      filters: @default_filters,
      flash: @default_flash,
      job: nil,
      jobs: Query.get_jobs(config, @default_filters),
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
        job = assigns.config.get(Job, jid)

        {:noreply, assign(socket, job: job)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(:tick, %{assigns: assigns} = socket) do
    updated = [
      jobs: Query.get_jobs(assigns.config, assigns.filters),
      node_stats: Stats.for_nodes(),
      queue_stats: Stats.for_queues(),
      state_stats: Stats.for_states()
    ]

    updated = maybe_refresh_job(updated, assigns)

    Process.send_after(self(), :tick, @tick_timing)

    {:noreply, assign(socket, updated)}
  end

  def handle_info(:clear_flash, %{assigns: assigns} = socket) do
    flash = Map.put(assigns.flash, :show, false)

    {:noreply, assign(socket, flash: flash)}
  end

  def handle_info(:close_modal, socket) do
    {:noreply, assign(socket, job: nil)}
  end

  def handle_info({:delete_job, job_id}, socket) do
    {:noreply, delete_job(job_id, socket)}
  end

  def handle_info({:deschedule_job, job_id}, socket) do
    {:noreply, deschedule_job(job_id, socket)}
  end

  def handle_info({:discard_job, job_id}, socket) do
    {:noreply, discard_job(job_id, socket)}
  end

  def handle_info({:kill_job, job_id}, socket) do
    {:noreply, kill_job(job_id, socket)}
  end

  @impl Phoenix.LiveView
  def handle_event("blitz_close", _value, socket) do
    handle_info(:clear_flash, socket)
  end

  def handle_event("change_node", %{"node" => node}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :node, node)
    jobs = Query.get_jobs(assigns.config, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_queue", %{"queue" => queue}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :queue, queue)
    jobs = Query.get_jobs(assigns.config, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_state", %{"state" => state}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :state, state)
    jobs = Query.get_jobs(assigns.config, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_terms", %{"terms" => terms}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :terms, terms)
    jobs = Query.get_jobs(assigns.config, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_worker", %{"worker" => worker}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :worker, worker)
    jobs = Query.get_jobs(assigns.config, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("clear_filter", %{"type" => type}, %{assigns: assigns} = socket) do
    type = String.to_existing_atom(type)
    default = Map.get(@default_filters, type)
    filters = Map.put(assigns.filters, type, default)
    jobs = Query.get_jobs(assigns.config, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("delete_job", %{"id" => job_id}, socket) do
    {:noreply, delete_job(String.to_integer(job_id), socket)}
  end

  def handle_event("kill_job", %{"id" => job_id}, socket) do
    {:noreply, kill_job(String.to_integer(job_id), socket)}
  end

  def handle_event("open_modal", %{"id" => job_id}, socket) do
    {:ok, job} = Query.fetch_job(socket.assigns.config, job_id)

    {:noreply, assign(socket, job: job)}
  end

  defp with_render_defaults(assigns) do
    Map.merge(@render_defaults, assigns)
  end

  defp maybe_refresh_job(updated, %{config: config, job: %Job{id: jid}}) do
    case Query.fetch_job(config.repo, jid) do
      {:ok, job} ->
        Keyword.put(updated, :job, job)

      {:error, :not_found} ->
        Keyword.put(updated, :job, nil)
    end
  end

  defp maybe_refresh_job(updated, _assigns) do
    updated
  end

  defp delete_job(job_id, socket) do
    :ok = Query.delete_job(socket.assigns.config, job_id)

    flash("Job deleted.", :alert, socket)
  end

  defp deschedule_job(job_id, socket) do
    :ok = Query.deschedule_job(socket.assigns.config, job_id)

    flash("Job staged for execution.", :alert, socket)
  end

  defp discard_job(job_id, socket) do
    :ok = Query.discard_job(socket.assigns.config, job_id)

    flash("Job discarded.", :alert, socket)
  end

  defp kill_job(job_id, socket) do
    :ok = Oban.kill_job(job_id)

    flash("Job canceled and discarded.", :alert, socket)
  end

  defp flash(message, mode, socket) do
    Process.send_after(self(), :clear_flash, @flash_timing)

    assign(socket, flash: %{show: true, mode: mode, message: message})
  end
end
