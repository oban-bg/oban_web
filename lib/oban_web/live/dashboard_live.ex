defmodule ObanWeb.DashboardLive do
  @moduledoc false

  use Phoenix.LiveView

  alias Oban.Job
  alias ObanWeb.{Config, DashboardView, Query, Stats}

  @flash_timing 5_000
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
    conf = Config.get()

    if connected?(socket), do: Process.send_after(self(), :tick, conf.tick_interval)

    :ok = Stats.activate()

    assigns = %{
      conf: conf,
      filters: @default_filters,
      job: nil,
      jobs: Query.get_jobs(conf, @default_filters),
      node_stats: Stats.for_nodes(conf.name),
      queue_stats: Stats.for_queues(conf.name),
      state_stats: Stats.for_states(conf.name),
      tick_ref: nil
    }

    {:ok, assign(socket, with_render_defaults(assigns))}
  end

  @impl Phoenix.LiveView
  def terminate(_reason, %{assigns: %{tick_ref: tick_ref}}) do
    if is_reference(tick_ref), do: Process.cancel_timer(tick_ref)

    :ok
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, %{assigns: assigns} = socket) do
    case params["jid"] do
      jid when is_binary(jid) ->
        job = assigns.conf.get(Job, jid)

        {:noreply, assign(socket, job: job)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info(:tick, %{assigns: assigns} = socket) do
    updated = [
      jobs: Query.get_jobs(assigns.conf, assigns.filters),
      node_stats: Stats.for_nodes(assigns.conf.name),
      queue_stats: Stats.for_queues(assigns.conf.name),
      state_stats: Stats.for_states(assigns.conf.name)
    ]

    tick_ref = Process.send_after(self(), :tick, assigns.conf.tick_interval)

    updated =
      updated
      |> maybe_refresh_job(assigns)
      |> Keyword.put(:tick_ref, tick_ref)

    {:noreply, assign(socket, updated)}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
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
    {:noreply, clear_flash(socket)}
  end

  def handle_event("change_node", %{"node" => node}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :node, node)
    jobs = Query.get_jobs(assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_queue", %{"queue" => queue}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :queue, queue)
    jobs = Query.get_jobs(assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_state", %{"state" => state}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :state, state)
    jobs = Query.get_jobs(assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_terms", %{"terms" => terms}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :terms, terms)
    jobs = Query.get_jobs(assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("change_worker", %{"worker" => worker}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :worker, worker)
    jobs = Query.get_jobs(assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("clear_filter", %{"type" => type}, %{assigns: assigns} = socket) do
    type = String.to_existing_atom(type)
    default = Map.get(@default_filters, type)
    filters = Map.put(assigns.filters, type, default)
    jobs = Query.get_jobs(assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_event("delete_job", %{"id" => job_id}, socket) do
    {:noreply, delete_job(String.to_integer(job_id), socket)}
  end

  def handle_event("kill_job", %{"id" => job_id}, socket) do
    {:noreply, kill_job(String.to_integer(job_id), socket)}
  end

  def handle_event("open_modal", %{"id" => job_id}, socket) do
    {:ok, job} = Query.fetch_job(socket.assigns.conf, job_id)

    {:noreply, assign(socket, job: job)}
  end

  defp with_render_defaults(assigns) do
    Map.merge(@render_defaults, assigns)
  end

  defp maybe_refresh_job(updated, %{conf: conf, job: %Job{id: jid}}) do
    case Query.fetch_job(conf, jid) do
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
    :ok = Query.delete_job(socket.assigns.conf, job_id)

    flash("Job deleted.", :info, socket)
  end

  defp deschedule_job(job_id, socket) do
    :ok = Query.deschedule_job(socket.assigns.conf, job_id)

    flash("Job staged for execution.", :info, socket)
  end

  defp discard_job(job_id, socket) do
    :ok = Query.discard_job(socket.assigns.conf, job_id)

    flash("Job discarded.", :info, socket)
  end

  defp kill_job(job_id, socket) do
    :ok = Oban.kill_job(job_id)

    flash("Job canceled and discarded.", :info, socket)
  end

  defp flash(message, mode, socket) do
    Process.send_after(self(), :clear_flash, @flash_timing)

    put_flash(socket, mode, message)
  end
end
