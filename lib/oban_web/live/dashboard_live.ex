defmodule ObanWeb.DashboardLive do
  use ObanWeb.Web, :live_view

  alias Oban.Job
  alias ObanWeb.{Config, Query, Stats}
  alias ObanWeb.{HeaderComponent, NotificationComponent, RefreshComponent}
  alias ObanWeb.{SearchComponent, SidebarComponent}

  @flash_timing 5_000

  @default_filters %{
    node: "any",
    queue: "any",
    state: "executing",
    terms: nil,
    worker: "any"
  }

  @default_refresh 1

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    :ok = Stats.activate()

    conf = Config.get()

    socket =
      assign(socket,
        conf: conf,
        filters: @default_filters,
        job: nil,
        jobs: Query.get_jobs(conf, @default_filters),
        node_stats: Stats.for_nodes(conf.name),
        queue_stats: Stats.for_queues(conf.name),
        state_stats: Stats.for_states(conf.name),
        refresh: @default_refresh,
        timer: nil
      )

    {:ok, init_schedule_refresh(socket)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~L"""
    <main role="main" class="p-4">
      <%= live_component @socket, NotificationComponent, id: :flash, flash: @flash %>

      <div class="flex justify-between">
        <span>Oban</span>
        <%= live_component @socket, RefreshComponent, id: :refresh, refresh: @refresh %>
      </div>

      <div class="w-full flex my-6">
        <div class="mr-3">
          <%= live_component @socket,
              SidebarComponent,
              id: :sidebar,
              filters: @filters,
              node_stats: @node_stats,
              queue_stats: @queue_stats,
              state_stats: @state_stats %>
        </div>

        <div class="flex-1 bg-white rounded-md shadow-md overflow-hidden">
          <div class="flex justify-between items-center border-b border-gray-200 px-3 py-3">
            <%= live_component @socket, HeaderComponent, id: :header, filters: @filters, jobs: @jobs, stats: @state_stats %>
            <%= live_component @socket, SearchComponent, id: :search, terms: @filters.terms %>
          </div>
        </div>
      </div>
    </main>
    """
  end

  @impl Phoenix.LiveView
  def terminate(_reason, %{assigns: %{timer: timer}}) do
    if is_reference(timer), do: Process.cancel_timer(timer)

    :ok
  end

  def terminate(_reason, _socket), do: :ok

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
  def handle_info(:refresh, socket) do
    socket =
      assign(socket,
        job: refresh_job(socket.assigns.conf, socket.assigns.job),
        jobs: Query.get_jobs(socket.assigns.conf, socket.assigns.filters),
        node_stats: Stats.for_nodes(socket.assigns.conf.name),
        queue_stats: Stats.for_queues(socket.assigns.conf.name),
        state_stats: Stats.for_states(socket.assigns.conf.name)
      )

    {:noreply, schedule_refresh(socket)}
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

  def handle_info({:scale_queue, queue, limit}, socket) do
    :ok = Oban.scale_queue(queue, limit)

    {:noreply, socket}
  end

  def handle_info({:pause_queue, queue}, socket) do
    :ok = Oban.pause_queue(queue)

    {:noreply, socket}
  end

  def handle_info({:resume_queue, queue}, socket) do
    :ok = Oban.resume_queue(queue)

    {:noreply, socket}
  end

  def handle_info({:filter_node, node}, socket) do
    filters = Map.put(socket.assigns.filters, :node, node)
    jobs = Query.get_jobs(socket.assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_info({:filter_state, state}, socket) do
    filters = Map.put(socket.assigns.filters, :state, state)
    jobs = Query.get_jobs(socket.assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_info({:filter_queue, queue}, socket) do
    filters = Map.put(socket.assigns.filters, :queue, queue)
    jobs = Query.get_jobs(socket.assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_info({:filter_terms, terms}, socket) do
    filters = Map.put(socket.assigns.filters, :terms, terms)
    jobs = Query.get_jobs(socket.assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
  end

  def handle_info({:update_refresh, refresh}, socket) do
    if is_reference(socket.assigns.timer), do: Process.cancel_timer(socket.assigns.timer)

    socket =
      socket
      |> assign(refresh: refresh)
      |> schedule_refresh()

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
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

  defp refresh_job(conf, %Job{id: jid}) do
    case Query.fetch_job(conf, jid) do
      {:ok, job} -> job
      {:error, :not_found} -> nil
    end
  end

  defp refresh_job(_conf, _job), do: nil

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

  ## Refresh Helpers

  defp init_schedule_refresh(socket) do
    if connected?(socket) do
      schedule_refresh(socket)
    else
      assign(socket, timer: nil)
    end
  end

  defp schedule_refresh(socket) do
    if socket.assigns.refresh > 0 do
      interval = :timer.seconds(socket.assigns.refresh) - 50

      assign(socket, timer: Process.send_after(self(), :refresh, interval))
    else
      assign(socket, timer: nil)
    end
  end
end
