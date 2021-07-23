defmodule Oban.Web.JobsComponent do
  use Oban.Web, :live_component

  alias Oban.Job
  alias Oban.Web.Jobs.{BulkActionComponent, DetailComponent, HeaderComponent, ListingComponent}
  alias Oban.Web.Jobs.{SearchComponent, SidebarComponent}
  alias Oban.Web.Plugins.Stats
  alias Oban.Web.{Query, Telemetry}

  @flash_timing 5_000

  def mount(socket) do
    {:ok, assign(socket, params: %{limit: 20, state: "executing"}, selected: MapSet.new())}
  end

  def update(assigns, socket) do
    # selected =
    #   assigns.jobs
    #   |> MapSet.new(& &1.id)
    #   |> MapSet.intersection(assigns.selected || MapSet.new())

    {:ok,
     assign(socket,
       access: assigns.access,
       detailed: assigns.detailed,
       user: assigns.user,
       jobs: assigns.jobs,
       params: socket.assigns.params,
       gossip: Stats.all_gossip(assigns.conf.name),
       counts: Stats.all_counts(assigns.conf.name),
       selected: socket.assigns.selected
     )}
  end

  def render(assigns) do
    ~L"""
    <div id="jobs-page" class="w-full flex flex-col my-6 md:flex-row">
      <div id="sidebar" class="mr-0 mb-3 md:mr-3 md:mb-0">
        <%= live_component @socket,
            SidebarComponent,
            id: :sidebar,
            access: @access,
            params: @params,
            gossip: @gossip,
            counts: @counts %>
      </div>

      <div class="flex-1 bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
        <%= if @detailed do %>
          <%= live_component @socket, DetailComponent, id: :detail, access: @access, job: @detailed %>
        <% else %>
          <div class="flex justify-between items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
            <%= live_component @socket, HeaderComponent, id: :header, params: @params, jobs: @jobs, counts: @counts, selected: @selected %>
            <%= live_component @socket, SearchComponent, id: :search, params: @params %>
          </div>

          <%= live_component @socket, BulkActionComponent, id: :bulk_action, access: @access, jobs: @jobs, selected: @selected %>
          <%= live_component @socket, ListingComponent, id: :listing, jobs: @jobs, params: @params, selected: @selected %>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_refresh(socket) do
    jobs = Query.get_jobs(socket.assigns.conf, socket.assigns.params)

    assign(socket,
      detailed: refresh_job(socket.assigns.conf, socket.assigns.detailed),
      jobs: jobs,
      gossip: Stats.all_gossip(socket.assigns.conf.name),
      counts: Stats.all_counts(socket.assigns.conf.name)
    )
  end

  def handle_params(%{"id" => job_id}, _uri, socket) do
    case refresh_job(socket.assigns.conf, %Job{id: job_id}) do
      nil ->
        {:noreply, socket}

      job ->
        {:noreply, assign(socket, detailed: job, page_title: page_title(job))}
    end
  end

  def handle_params(params, _uri, socket) do
    normalize = fn
      {"limit", limit} -> {:limit, String.to_integer(limit)}
      {key, val} -> {String.to_existing_atom(key), val}
    end

    params =
      params
      |> Map.take(["limit", "node", "queue", "state", "terms"])
      |> Map.new(normalize)

    jobs = Query.get_jobs(socket.assigns.conf, params)

    {:noreply,
     assign(socket, detailed: nil, jobs: jobs, params: params, page_title: page_title("Jobs"))}
  end

  # Queues

  def handle_info({:scale_queue, queue, limit}, socket) do
    Telemetry.action(:scale_queue, socket, [queue: queue, limit: limit], fn ->
      Oban.scale_queue(socket.assigns.conf.name, queue: queue, limit: limit)
    end)

    {:noreply, socket}
  end

  # Filtering

  def handle_info({:params, :limit, inc}, socket) when is_integer(inc) do
    params = Map.update!(socket.assigns.params, :limit, &to_string(&1 + inc))

    {:noreply, push_patch(socket, to: oban_path(socket, :jobs, params), replace: true)}
  end

  def handle_info({:params, key, value}, socket) do
    params =
      if is_nil(value) do
        Map.delete(socket.assigns.params, key)
      else
        Map.put(socket.assigns.params, key, value)
      end

    {:noreply, push_patch(socket, to: oban_path(socket, :jobs, params), replace: true)}
  end

  # Single Actions

  def handle_info({:cancel_job, job}, socket) do
    Telemetry.action(:cancel_jobs, socket, [job_ids: [job.id]], fn ->
      Oban.cancel_job(socket.assigns.conf.name, job.id)
    end)

    job = %{job | state: "cancelled", cancelled_at: DateTime.utc_now()}

    {:noreply, assign(socket, detailed: job)}
  end

  def handle_info({:delete_job, job}, socket) do
    Telemetry.action(:delete_jobs, socket, [job_ids: [job.id]], fn ->
      Query.delete_jobs(socket.assigns.conf, [job.id])
    end)

    {:noreply, assign(socket, detailed: nil)}
  end

  def handle_info({:retry_job, job}, socket) do
    Telemetry.action(:retry_jobs, socket, [job_ids: [job.id]], fn ->
      Query.deschedule_jobs(socket.assigns.conf, [job.id])
    end)

    job = %{job | state: "available", completed_at: nil, discarded_at: nil}

    {:noreply, assign(socket, detailed: job)}
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
    job_ids = MapSet.to_list(socket.assigns.selected)

    Telemetry.action(:cancel_jobs, socket, [job_ids: job_ids], fn ->
      Query.cancel_jobs(socket.assigns.conf, job_ids)
    end)

    socket =
      socket
      |> hide_and_clear_selected()
      |> flash(:info, "Selected jobs canceled")

    {:noreply, handle_refresh(socket)}
  end

  def handle_info(:retry_selected, socket) do
    job_ids = MapSet.to_list(socket.assigns.selected)

    Telemetry.action(:retry_jobs, socket, [job_ids: job_ids], fn ->
      Query.deschedule_jobs(socket.assigns.conf, job_ids)
    end)

    socket =
      socket
      |> hide_and_clear_selected()
      |> flash(:info, "Selected jobs scheduled to run immediately")

    {:noreply, handle_refresh(socket)}
  end

  def handle_info(:delete_selected, socket) do
    job_ids = MapSet.to_list(socket.assigns.selected)

    Telemetry.action(:delete_jobs, socket, [job_ids: job_ids], fn ->
      Query.delete_jobs(socket.assigns.conf, job_ids)
    end)

    socket =
      socket
      |> hide_and_clear_selected()
      |> flash(:info, "Selected jobs deleted")

    {:noreply, handle_refresh(socket)}
  end

  # Helpers

  defp flash(socket, mode, message) do
    Process.send_after(self(), :clear_flash, @flash_timing)

    put_flash(socket, mode, message)
  end

  defp hide_and_clear_selected(socket) do
    %{jobs: jobs, selected: selected} = socket.assigns

    jobs = for job <- jobs, do: Map.put(job, :hidden?, MapSet.member?(selected, job.id))

    assign(socket, jobs: jobs, selected: MapSet.new())
  end

  defp refresh_job(conf, %Job{id: jid}) do
    case Query.fetch_job(conf, jid) do
      {:ok, job} -> job
      {:error, :not_found} -> nil
    end
  end

  defp refresh_job(_conf, _job), do: nil
end
