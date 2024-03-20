defmodule Oban.Web.JobsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Met
  alias Oban.Web.Jobs.{BulkActionComponent, ChartComponent, DetailComponent, HeaderComponent}
  alias Oban.Web.Jobs.{SearchComponent, SidebarComponent, SortComponent, TableComponent}
  alias Oban.Web.{Page, Query, Telemetry}

  @flash_timing 5_000
  @known_params ~w(args ids limit meta nodes priorities queues sort_by sort_dir state tags workers)
  @ordered_states ~w(executing available scheduled retryable cancelled discarded completed)

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="jobs-page" class="flex-1 w-full flex flex-col my-6 md:flex-row">
      <.live_component
        id="sidebar"
        module={SidebarComponent}
        nodes={@nodes}
        params={without_defaults(@params, @default_params)}
        queues={@queues}
        states={@states}
      />

      <div class="flex-grow">
        <.live_component
          :if={is_nil(@detailed)}
          id="chart"
          conf={@conf}
          init_state={@init_state}
          module={ChartComponent}
          os_time={@os_time}
          params={@params}
        />

        <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg">
          <%= if @detailed do %>
            <.live_component
              id="detail"
              access={@access}
              job={@detailed}
              module={DetailComponent}
              os_time={@os_time}
              params={without_defaults(Map.delete(@params, "id"), @default_params)}
              resolver={@resolver}
            />
          <% else %>
            <div class="flex items-start justify-between space-x-3 px-3 py-3 border-b border-gray-200 dark:border-gray-700">
              <.live_component
                id="header"
                module={HeaderComponent}
                jobs={@jobs}
                params={@params}
                selected={@selected}
              />
              <.live_component
                id="search"
                module={SearchComponent}
                conf={@conf}
                params={without_defaults(@params, @default_params)}
                resolver={@resolver}
              />
              <.live_component id="sorter" module={SortComponent} params={@params} />
            </div>

            <.live_component
              id="jobs-bulk-action"
              module={BulkActionComponent}
              access={@access}
              jobs={@jobs}
              selected={@selected}
            />

            <.live_component
              id="jobs-table"
              conf={@conf}
              jobs={@jobs}
              module={TableComponent}
              params={@params}
              resolver={@resolver}
              selected={@selected}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) do
    default = fn ->
      %{limit: 20, sort_by: "time", sort_dir: "asc", state: "executing"}
    end

    socket
    |> assign_new(:default_params, default)
    |> assign_new(:detailed, fn -> nil end)
    |> assign_new(:jobs, fn -> [] end)
    |> assign_new(:nodes, fn -> [] end)
    |> assign_new(:os_time, fn -> System.os_time(:second) end)
    |> assign_new(:params, default)
    |> assign_new(:queues, fn -> [] end)
    |> assign_new(:selected, &MapSet.new/0)
    |> assign_new(:states, fn -> [] end)
  end

  @impl Page
  def handle_refresh(socket) do
    %{conf: conf, params: params, resolver: resolver} = socket.assigns

    jobs = Query.all_jobs(params, conf, resolver: resolver)

    selected =
      jobs
      |> MapSet.new(& &1.id)
      |> MapSet.intersection(socket.assigns.selected)

    assign(socket,
      detailed: Query.refresh_job(conf, socket.assigns.detailed),
      jobs: jobs,
      nodes: nodes(conf),
      os_time: System.os_time(:second),
      queues: queues(conf),
      selected: selected,
      states: states(conf)
    )
  end

  @impl Page
  def handle_params(%{"id" => job_id} = params, _uri, socket) do
    params = params_with_defaults(params, socket)

    case Query.refresh_job(socket.assigns.conf, job_id) do
      nil ->
        {:noreply, push_patch(socket, to: oban_path(:jobs), replace: true)}

      job ->
        {:noreply,
         socket
         |> assign(detailed: job, page_title: page_title(job))
         |> assign(params: params)}
    end
  end

  def handle_params(params, _uri, socket) do
    %{conf: conf, resolver: resolver} = socket.assigns

    params = params_with_defaults(params, socket)

    socket =
      socket
      |> assign(detailed: nil, page_title: page_title("Jobs"))
      |> assign(params: params)
      |> assign(jobs: Query.all_jobs(params, conf, resolver: resolver))
      |> assign(nodes: nodes(conf), queues: queues(conf), states: states(conf))

    {:noreply, socket}
  end

  # Queues

  @impl Page
  def handle_info({ref, _val}, socket) when is_reference(ref) do
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, socket) do
    {:noreply, socket}
  end

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

    {:noreply, push_patch(socket, to: oban_path(:jobs), replace: true)}
  end

  def handle_info({:retry_job, job}, socket) do
    Telemetry.action(:retry_jobs, socket, [job_ids: [job.id]], fn ->
      Query.retry_jobs(socket.assigns.conf, [job.id])
    end)

    job = %{job | state: "available", completed_at: nil, discarded_at: nil}

    {:noreply, assign(socket, detailed: job)}
  end

  # Selection

  def handle_info({:toggle_select, job_id}, socket) do
    selected = socket.assigns.selected

    selected =
      if MapSet.member?(selected, job_id) do
        MapSet.delete(selected, job_id)
      else
        MapSet.put(selected, job_id)
      end

    {:noreply, assign(socket, selected: selected)}
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

  # Param Helpers

  defp params_with_defaults(params, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> Query.decode_params()

    Map.merge(socket.assigns.default_params, params)
  end

  # Socket Helpers

  defp hide_and_clear_selected(socket) do
    %{jobs: jobs, selected: selected} = socket.assigns

    jobs = for job <- jobs, do: Map.put(job, :hidden?, MapSet.member?(selected, job.id))

    assign(socket, jobs: jobs, selected: MapSet.new())
  end

  defp flash(socket, mode, message) do
    Process.send_after(self(), :clear_flash, @flash_timing)

    put_flash(socket, mode, message)
  end

  # Metrics Helpers

  def nodes(conf) do
    conf.name
    |> Met.checks()
    |> Enum.reduce(%{}, fn check, acc ->
      node = check["node"]
      count = length(check["running"])
      limit = check["local_limit"] || check["limit"]

      acc
      |> Map.put_new(node, %{name: node, count: 0, limit: 0})
      |> update_in([node, :count], &(&1 + count))
      |> update_in([node, :limit], &(&1 + limit))
    end)
    |> Map.values()
    |> Enum.sort_by(& &1.name)
  end

  def states(conf) do
    counts = Met.latest(conf.name, :full_count, group: "state")

    for state <- @ordered_states do
      %{name: state, count: Map.get(counts, state, 0)}
    end
  end

  def queues(conf) do
    avail_counts =
      Met.latest(conf.name, :full_count, group: "queue", filters: [state: "available"])

    execu_counts =
      Met.latest(conf.name, :full_count, group: "queue", filters: [state: "executing"])

    conf.name
    |> Met.checks()
    |> Enum.reduce(%{}, fn %{"queue" => queue} = check, acc ->
      empty = fn ->
        %{
          name: queue,
          avail: Map.get(avail_counts, queue, 0),
          execu: Map.get(execu_counts, queue, 0),
          limit: 0,
          all_paused?: true,
          any_paused?: false,
          global?: false,
          rate_limited?: false
        }
      end

      acc
      |> Map.put_new_lazy(queue, empty)
      |> update_in([queue, :limit], &check_limit(&1, check))
      |> update_in([queue, :global?], &(&1 or is_map(check["global_limit"])))
      |> update_in([queue, :rate_limited?], &(&1 or is_map(check["rate_limit"])))
      |> update_in([queue, :all_paused?], &(&1 and check["paused"]))
      |> update_in([queue, :any_paused?], &(&1 or check["paused"]))
    end)
    |> Map.values()
    |> Enum.sort_by(& &1.name)
  end

  defp check_limit(_total, %{"global_limit" => %{"allowed" => limit}}), do: limit
  defp check_limit(total, %{"local_limit" => limit}) when is_integer(limit), do: total + limit
  defp check_limit(total, %{"limit" => limit}) when is_integer(limit), do: total + limit
  defp check_limit(total, _payload), do: total
end
