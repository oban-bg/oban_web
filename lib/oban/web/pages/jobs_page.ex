defmodule Oban.Web.JobsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Met
  alias Oban.Web.Jobs.{ChartComponent, DetailComponent}
  alias Oban.Web.Jobs.{SidebarComponent, TableComponent}
  alias Oban.Web.{JobQuery, Page, QueueQuery, SearchComponent, SortComponent, Telemetry}

  @known_params ~w(args ids limit meta nodes priorities queues sort_by sort_dir state tags workers)
  @ordered_states ~w(executing available scheduled retryable cancelled discarded completed)

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="jobs-page" class="flex-1 w-full flex flex-col my-6 md:flex-row">
      <SidebarComponent.sidebar
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
            <div class="flex items-start pr-3 py-3 border-b border-gray-200 dark:border-gray-700">
              <div id="jobs-header" class="h-10 pr-12 flex-none flex items-center">
                <Core.all_checkbox
                  click="toggle-select-all"
                  checked={checked_mode(@jobs, @selected)}
                  myself={@myself}
                />

                <h2 class="text-base font-semibold dark:text-gray-200">Jobs</h2>
              </div>

              <div
                :if={Enum.any?(@selected)}
                id="bulk-actions"
                class="pt-1 flex items-center space-x-3"
              >
                <Core.action_button
                  :if={cancelable?(@jobs, @access)}
                  label="Cancel"
                  click="cancel-jobs"
                  target={@myself}
                >
                  <:icon><Icons.x_circle class="w-5 h-5" /></:icon>
                  <:title>Cancel Jobs</:title>
                </Core.action_button>

                <Core.action_button
                  :if={retryable?(@jobs, @access)}
                  label="Retry"
                  click="retry-jobs"
                  target={@myself}
                >
                  <:icon><Icons.arrow_right_circle class="w-5 h-5" /></:icon>
                  <:title>Retry Jobs</:title>
                </Core.action_button>

                <Core.action_button
                  :if={runnable?(@jobs, @access)}
                  label="Run Now"
                  click="retry-jobs"
                  target={@myself}
                >
                  <:icon><Icons.arrow_right_circle class="w-5 h-5" /></:icon>
                  <:title>Run Jobs Now</:title>
                </Core.action_button>

                <Core.action_button
                  :if={deletable?(@jobs, @access)}
                  label="Delete"
                  click="delete-jobs"
                  target={@myself}
                  danger={true}
                >
                  <:icon><Icons.trash class="w-5 h-5" /></:icon>
                  <:title>Delete Jobs</:title>
                </Core.action_button>
              </div>

              <.live_component
                :if={Enum.empty?(@selected)}
                conf={@conf}
                id="search"
                module={SearchComponent}
                page={:jobs}
                params={without_defaults(@params, @default_params)}
                queryable={JobQuery}
                resolver={@resolver}
              />

              <div class="pl-3 ml-auto">
                <span :if={Enum.any?(@selected)} class="block py-2 text-sm font-semibold">
                  {MapSet.size(@selected)} Selected
                </span>

                <SortComponent.select
                  :if={Enum.empty?(@selected)}
                  params={@params}
                  by={~w(time attempt queue worker)}
                />
              </div>
            </div>

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

    jobs = JobQuery.all_jobs(params, conf, resolver: resolver)

    selected =
      if Enum.any?(socket.assigns.selected) do
        all_job_ids = JobQuery.all_job_ids(params, conf, resolver: resolver)

        all_job_ids
        |> MapSet.new()
        |> MapSet.intersection(socket.assigns.selected)
      else
        MapSet.new()
      end

    assign(socket,
      detailed: JobQuery.refresh_job(conf, socket.assigns.detailed),
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

    case JobQuery.refresh_job(socket.assigns.conf, job_id) do
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
      |> assign(jobs: JobQuery.all_jobs(params, conf, resolver: resolver))
      |> assign(nodes: nodes(conf), queues: queues(conf), states: states(conf))

    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-select-all", _params, socket) do
    send(self(), :toggle_select_all)

    {:noreply, socket}
  end

  def handle_event("cancel-jobs", _params, socket) do
    if can?(:cancel_jobs, socket.assigns.access) do
      send(self(), :cancel_selected)
    end

    {:noreply, assign(socket, expanded?: false)}
  end

  def handle_event("retry-jobs", _params, socket) do
    if can?(:retry_jobs, socket.assigns.access) do
      send(self(), :retry_selected)
    end

    {:noreply, assign(socket, expanded?: false)}
  end

  def handle_event("delete-jobs", _params, socket) do
    if can?(:delete_jobs, socket.assigns.access) do
      send(self(), :delete_selected)
    end

    {:noreply, assign(socket, expanded?: false)}
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
      JobQuery.delete_jobs(socket.assigns.conf, [job.id])
    end)

    {:noreply, push_patch(socket, to: oban_path(:jobs), replace: true)}
  end

  def handle_info({:retry_job, job}, socket) do
    Telemetry.action(:retry_jobs, socket, [job_ids: [job.id]], fn ->
      JobQuery.retry_jobs(socket.assigns.conf, [job.id])
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

  def handle_info(:toggle_select_all, socket) do
    selected =
      if Enum.any?(socket.assigns.selected) do
        MapSet.new()
      else
        # Always include the jobs we can see currently to compensate for slower refresh rates.
        # Without this, visible jobs may not be selected and the interface looks broken.
        local_set = MapSet.new(socket.assigns.jobs, & &1.id)

        socket.assigns.params
        |> JobQuery.all_job_ids(socket.assigns.conf)
        |> MapSet.new()
        |> MapSet.union(local_set)
      end

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_info(:cancel_selected, socket) do
    job_ids = MapSet.to_list(socket.assigns.selected)

    Telemetry.action(:cancel_jobs, socket, [job_ids: job_ids], fn ->
      JobQuery.cancel_jobs(socket.assigns.conf, job_ids)
    end)

    socket =
      socket
      |> hide_and_clear_selected()
      |> put_flash_with_clear(:info, "Selected jobs canceled")

    {:noreply, handle_refresh(socket)}
  end

  def handle_info(:retry_selected, socket) do
    job_ids = MapSet.to_list(socket.assigns.selected)

    Telemetry.action(:retry_jobs, socket, [job_ids: job_ids], fn ->
      JobQuery.retry_jobs(socket.assigns.conf, job_ids)
    end)

    socket =
      socket
      |> hide_and_clear_selected()
      |> put_flash_with_clear(:info, "Selected jobs scheduled to run immediately")

    {:noreply, handle_refresh(socket)}
  end

  def handle_info(:delete_selected, socket) do
    job_ids = MapSet.to_list(socket.assigns.selected)

    Telemetry.action(:delete_jobs, socket, [job_ids: job_ids], fn ->
      JobQuery.delete_jobs(socket.assigns.conf, job_ids)
    end)

    socket =
      socket
      |> hide_and_clear_selected()
      |> put_flash_with_clear(:info, "Selected jobs deleted")

    {:noreply, handle_refresh(socket)}
  end

  # Param Helpers

  defp params_with_defaults(params, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params()

    Map.merge(socket.assigns.default_params, params)
  end

  # Socket Helpers

  defp hide_and_clear_selected(socket) do
    %{jobs: jobs, selected: selected} = socket.assigns

    jobs = for job <- jobs, do: Map.put(job, :hidden?, MapSet.member?(selected, job.id))

    assign(socket, jobs: jobs, selected: MapSet.new())
  end

  # State Helpers

  defp checked_mode(jobs, selected) do
    cond do
      Enum.empty?(selected) -> :none
      Enum.all?(jobs, &MapSet.member?(selected, &1.id)) -> :all
      true -> :some
    end
  end

  defp cancelable?(jobs, access) do
    can?(:cancel_jobs, access) and Enum.any?(jobs, &cancelable?/1)
  end

  defp runnable?(jobs, access) do
    can?(:retry_jobs, access) and Enum.any?(jobs, &runnable?/1)
  end

  defp retryable?(jobs, access) do
    can?(:retry_jobs, access) and Enum.any?(jobs, &retryable?/1)
  end

  defp deletable?(jobs, access) do
    can?(:delete_jobs, access) and Enum.any?(jobs, &deletable?/1)
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
    QueueQuery.all_queues(%{}, conf)
  end
end
