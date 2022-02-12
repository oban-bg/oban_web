defmodule Oban.Web.JobsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Web.Jobs.{BulkActionComponent, DetailComponent, HeaderComponent, TableComponent}
  alias Oban.Web.Jobs.SearchComponent
  alias Oban.Web.Plugins.Stats
  alias Oban.Web.{Page, Query, SidebarComponent, Telemetry}

  @flash_timing 5_000

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="jobs-page" class="flex-1 w-full flex flex-col my-6 md:flex-row">
      <.live_component
        id="sidebar"
        module={SidebarComponent}
        sections={~w(nodes states queues)a}
        counts={@counts}
        gossip={@gossip}
        page={:jobs}
        params={without_defaults(@params, @default_params)}
        socket={@socket} />

      <div class="flex-grow">
        <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
          <%= if @detailed do %>
            <.live_component
              id="detail"
              access={@access}
              job={@detailed}
              module={DetailComponent}
              params={without_defaults(Map.delete(@params, "id"), @default_params)}
              resolver={@resolver} />
          <% else %>
            <div class="flex justify-between items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
              <.live_component id="header" module={HeaderComponent} params={@params} jobs={@jobs} counts={@counts} selected={@selected} />
              <.live_component id="search" module={SearchComponent} params={@params} />
            </div>

            <.live_component id="bulk_action" module={BulkActionComponent} access={@access} jobs={@jobs} selected={@selected} />

            <.live_component
              id="jobs-table"
              module={TableComponent}
              jobs={@jobs}
              params={@params}
              resolver={@resolver}
              selected={@selected} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) do
    default = fn ->
      %{limit: 20, sort_by: "time", sort_dir: "desc", state: "executing", terms: nil}
    end

    socket
    |> assign_new(:detailed, fn -> nil end)
    |> assign_new(:jobs, fn -> [] end)
    |> assign_new(:params, default)
    |> assign_new(:default_params, default)
    |> assign_new(:selected, &MapSet.new/0)
    |> assign_new(:gossip, fn -> Stats.all_gossip(socket.assigns.conf.name) end)
    |> assign_new(:counts, fn -> Stats.all_counts(socket.assigns.conf.name) end)
  end

  @impl Page
  def handle_refresh(socket) do
    jobs = Query.all_jobs(socket.assigns.conf, socket.assigns.params)

    selected =
      jobs
      |> MapSet.new(& &1.id)
      |> MapSet.intersection(socket.assigns.selected)

    assign(socket,
      detailed: refresh_job(socket.assigns.conf, socket.assigns.detailed),
      jobs: jobs,
      gossip: Stats.all_gossip(socket.assigns.conf.name),
      counts: Stats.all_counts(socket.assigns.conf.name),
      selected: selected
    )
  end

  @impl Page
  def handle_params(%{"id" => job_id}, _uri, socket) do
    case refresh_job(socket.assigns.conf, job_id) do
      nil ->
        {:noreply, patch_to_jobs(socket)}

      job ->
        {:noreply, assign(socket, detailed: job, page_title: page_title(job))}
    end
  end

  def handle_params(params, _uri, socket) do
    params = params_with_defaults(params, socket)

    socket =
      socket
      |> assign(detailed: nil, page_title: page_title("Jobs"))
      |> assign(params: params)
      |> assign(jobs: Query.all_jobs(socket.assigns.conf, params))

    {:noreply, socket}
  end

  # Queues

  @impl Page
  def handle_info({:scale_queue, queue, limit}, socket) do
    Telemetry.action(:scale_queue, socket, [queue: queue, limit: limit], fn ->
      Oban.scale_queue(socket.assigns.conf.name, queue: queue, limit: limit)
    end)

    {:noreply, socket}
  end

  # Filtering

  def handle_info({:params, :limit, inc}, socket) when is_integer(inc) do
    params =
      socket.assigns.params
      |> Map.update!(:limit, &to_string(&1 + inc))
      |> without_defaults(socket.assigns.default_params)

    {:noreply, push_patch(socket, to: oban_path(:jobs, params), replace: true)}
  end

  def handle_info({:params, :terms, terms}, socket) do
    params =
      socket.assigns.params
      |> Map.put(:terms, terms)
      |> without_defaults(socket.assigns.default_params)

    {:noreply, push_patch(socket, to: oban_path(:jobs, params), replace: true)}
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

    {:noreply, patch_to_jobs(socket)}
  end

  def handle_info({:retry_job, job}, socket) do
    Telemetry.action(:retry_jobs, socket, [job_ids: [job.id]], fn ->
      Query.retry_jobs(socket.assigns.conf, [job.id])
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
      Query.retry_jobs(socket.assigns.conf, job_ids)
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

  defp params_with_defaults(params, socket) do
    normalize = fn
      {"limit", limit} -> {:limit, String.to_integer(limit)}
      {"nodes", nodes} -> {:nodes, String.split(nodes, ",")}
      {"queues", queues} -> {:queues, String.split(queues, ",")}
      {key, val} -> {String.to_existing_atom(key), val}
    end

    params =
      params
      |> Map.take(["limit", "nodes", "queues", "sort_by", "sort_dir", "state", "terms"])
      |> Map.new(normalize)

    Map.merge(socket.assigns.default_params, params)
  end

  defp patch_to_jobs(socket) do
    push_patch(socket, to: oban_path(:jobs), replace: true)
  end

  defp refresh_job(conf, job_or_jid) do
    Query.refresh_job(conf, job_or_jid)
  end
end
