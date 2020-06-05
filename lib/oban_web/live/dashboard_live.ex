defmodule ObanWeb.DashboardLive do
  use ObanWeb.Web, :live_view

  alias Oban.Job
  alias ObanWeb.{Config, Query, Stats}
  alias ObanWeb.{BulkActionComponent, HeaderComponent, ListingComponent, NotificationComponent}
  alias ObanWeb.{RefreshComponent, SearchComponent, SidebarComponent}

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
        selected: MapSet.new(),
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

        <div class="flex-1 bg-white rounded-md shadow-md">
          <div class="flex justify-between items-center border-b border-gray-200 px-3 py-3">
            <%= live_component @socket, HeaderComponent, id: :header, filters: @filters, jobs: @jobs, stats: @state_stats, selected: @selected %>
            <%= live_component @socket, SearchComponent, id: :search, terms: @filters.terms %>
          </div>

          <%= live_component @socket, BulkActionComponent, id: :bulk_action, jobs: @jobs, selected: @selected %>
          <%= live_component @socket, ListingComponent, id: :listing, jobs: @jobs, selected: @selected %>
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
    jobs = Query.get_jobs(socket.assigns.conf, socket.assigns.filters)

    selected =
      jobs
      |> MapSet.new(& &1.id)
      |> MapSet.intersection(socket.assigns.selected)

    socket =
      assign(socket,
        job: refresh_job(socket.assigns.conf, socket.assigns.job),
        jobs: jobs,
        node_stats: Stats.for_nodes(socket.assigns.conf.name),
        queue_stats: Stats.for_queues(socket.assigns.conf.name),
        state_stats: Stats.for_states(socket.assigns.conf.name),
        selected: selected
      )

    {:noreply, schedule_refresh(socket)}
  end

  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info(:close_modal, socket) do
    {:noreply, assign(socket, job: nil)}
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

  # Filtering

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
    socket =
      socket
      |> assign(refresh: refresh)
      |> schedule_refresh()

    {:noreply, socket}
  end

  # Selection

  def handle_info({:select_job, job}, socket) do
    {:noreply, assign(socket, selected: MapSet.put(socket.assigns.selected, job.id))}
  end

  def handle_info({:deselect_job, job}, socket) do
    {:noreply, assign(socket, selected: MapSet.delete(socket.assigns.selected, job.id))}
  end

  def handle_info(:select_all, socket) do
    {:noreply, assign(socket, selected: MapSet.new(socket.assigns.jobs, & &1.id))}
  end

  def handle_info(:deselect_all, socket) do
    {:noreply, assign(socket, selected: MapSet.new())}
  end

  def handle_info(:cancel_selected, socket) do
    :ok = Enum.each(socket.assigns.selected, &Oban.cancel_job/1)

    socket =
      socket
      |> hide_and_clear_selected()
      |> force_schedule_refresh()
      |> flash(:info, "Selected jobs canceled and discarded")

    {:noreply, socket}
  end

  def handle_info(:retry_selected, socket) do
    Query.deschedule_jobs(socket.assigns.conf, MapSet.to_list(socket.assigns.selected))

    socket =
      socket
      |> hide_and_clear_selected()
      |> force_schedule_refresh()
      |> flash(:info, "Selected jobs scheduled to run immediately")

    {:noreply, socket}
  end

  def handle_info(:delete_selected, socket) do
    Query.delete_jobs(socket.assigns.conf, MapSet.to_list(socket.assigns.selected))

    socket =
      socket
      |> hide_and_clear_selected()
      |> force_schedule_refresh()
      |> flash(:info, "Selected jobs deleted")

    {:noreply, socket}
  end

  # Events

  @impl Phoenix.LiveView
  def handle_event("change_worker", %{"worker" => worker}, %{assigns: assigns} = socket) do
    filters = Map.put(assigns.filters, :worker, worker)
    jobs = Query.get_jobs(assigns.conf, filters)

    {:noreply, assign(socket, jobs: jobs, filters: filters)}
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

  ## Update Helpers

  defp flash(socket, mode, message) do
    Process.send_after(self(), :clear_flash, @flash_timing)

    put_flash(socket, mode, message)
  end

  defp hide_and_clear_selected(socket) do
    %{jobs: jobs, selected: selected} = socket.assigns

    jobs = for job <- jobs, do: Map.put(job, :hidden?, MapSet.member?(selected, job.id))

    assign(socket, jobs: jobs, selected: MapSet.new())
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
    if is_reference(socket.assigns.timer), do: Process.cancel_timer(socket.assigns.timer)

    if socket.assigns.refresh > 0 do
      interval = :timer.seconds(socket.assigns.refresh) - 50

      assign(socket, timer: Process.send_after(self(), :refresh, interval))
    else
      assign(socket, timer: nil)
    end
  end

  defp force_schedule_refresh(socket, override \\ 1) do
    original = socket.assigns.refresh

    socket
    |> assign(refresh: override)
    |> schedule_refresh()
    |> assign(refresh: original)
  end
end
