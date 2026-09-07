defmodule Oban.Web.JobsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Met

  alias Oban.Web.{
    Colors,
    JobQuery,
    Metrics,
    Page,
    QueueQuery,
    Resolver,
    Search,
    SearchComponent,
    SortComponent,
    Telemetry,
    WorkflowQuery
  }

  alias Oban.Web.Jobs.{ChartComponent, DetailComponent, NewComponent}
  alias Oban.Web.Jobs.{SidebarComponent, TableComponent}

  @known_params JobQuery.known_params() ++ ~w(limit sort_by sort_dir)
  @ordered_states ~w(executing available suspended scheduled retryable cancelled discarded completed)

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:show_new_form, fn -> false end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="jobs-page" class="flex-1 w-full flex flex-col my-6 md:flex-row">
      <SidebarComponent.sidebar
        :if={is_nil(@detailed)}
        collapsed={@sidebar_collapsed}
        nodes={@nodes}
        params={without_defaults(@params, @default_params)}
        queues={@queues}
        states={@states}
        width={@sidebar_width}
        csp_nonces={@csp_nonces}
      />

      <div class="flex-grow">
        <.live_component
          :if={is_nil(@detailed)}
          id="chart"
          conf={@conf}
          init_state={@init_state}
          module={ChartComponent}
          os_time={@os_time}
          params={without_defaults(@params, @default_params)}
        />

        <div class={[
          "bg-white dark:bg-gray-900 rounded-md shadow-lg",
          @detailed && "mx-4"
        ]}>
          <%= if @detailed do %>
            <.live_component
              id="detail"
              access={@access}
              conf={@conf}
              diagnostics={@diagnostics}
              diagnostics_at={@diagnostics_at}
              history={@history}
              init_state={@init_state}
              chunk_counts={@chunk_counts}
              chunk_leader={@chunk_leader}
              compensating_job={@compensating_job}
              job={@detailed}
              module={DetailComponent}
              os_time={@os_time}
              params={without_defaults(Map.delete(@params, "id"), @default_params)}
              queues={@queues}
              resolver={@resolver}
            />
          <% else %>
            <div class="sticky top-0 z-20 flex items-start pr-3 py-3 rounded-t-md bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700">
              <div id="jobs-header" class="h-10 pr-12 flex-none flex items-center">
                <Core.all_checkbox
                  click="toggle-select-all"
                  checked={checked_mode(@jobs, @selected)}
                  myself={@myself}
                />

                <h2 class="flex items-center text-base font-semibold dark:text-gray-200">
                  Jobs <.state_chip state={@params.state} />
                </h2>
              </div>

              <.live_component
                conf={@conf}
                id="search"
                module={SearchComponent}
                page={:jobs}
                params={without_defaults(@params, @default_params)}
                queryable={JobQuery}
                resolver={@resolver}
              />

              <div class="pl-3 ml-auto flex items-center">
                <div
                  :if={Enum.any?(@selected)}
                  id="bulk-actions"
                  class="h-10 flex items-center space-x-3"
                >
                  <.selection_count
                    count={MapSet.size(@selected)}
                    limit={bulk_limit(@resolver, @params)}
                  />

                  <Core.action_button
                    :if={cancelable?(@jobs, @access)}
                    label="Cancel"
                    click="cancel-jobs"
                    confirm={bulk_confirm(:cancel, @selected, @params)}
                    target={@myself}
                  >
                    <:icon><Icons.icon name="icon-x-circle" class="w-5 h-5" /></:icon>
                    <:title>Cancel Jobs</:title>
                  </Core.action_button>

                  <Core.action_button
                    :if={retryable?(@jobs, @access)}
                    label="Retry"
                    click="retry-jobs"
                    confirm={bulk_confirm(:retry, @selected, @params)}
                    target={@myself}
                  >
                    <:icon><Icons.icon name="icon-arrow-right-circle" class="w-5 h-5" /></:icon>
                    <:title>Retry Jobs</:title>
                  </Core.action_button>

                  <Core.action_button
                    :if={runnable?(@jobs, @access)}
                    label="Run Now"
                    click="retry-jobs"
                    confirm={bulk_confirm(:run, @selected, @params)}
                    target={@myself}
                  >
                    <:icon><Icons.icon name="icon-arrow-right-circle" class="w-5 h-5" /></:icon>
                    <:title>Run Jobs Now</:title>
                  </Core.action_button>

                  <Core.action_button
                    :if={deletable?(@jobs, @access)}
                    label="Delete"
                    click="delete-jobs"
                    confirm={bulk_confirm(:delete, @selected, @params)}
                    target={@myself}
                    danger={true}
                  >
                    <:icon><Icons.icon name="icon-trash" class="w-5 h-5" /></:icon>
                    <:title>Delete Jobs</:title>
                  </Core.action_button>
                </div>

                <SortComponent.select
                  :if={Enum.empty?(@selected)}
                  by={~w(time attempt queue worker)}
                  defaults={@default_params}
                  params={@params}
                />

                <.link
                  :if={Enum.empty?(@selected)}
                  patch={can?(:insert_jobs, @access) && oban_path([:jobs, :new])}
                  id="new-job-button"
                  data-title="Create a new job"
                  phx-hook="Tippy"
                  aria-disabled={not can?(:insert_jobs, @access)}
                  class={[
                    "ml-3 h-10 flex items-center text-sm bg-white dark:bg-gray-800 px-3 py-2 border rounded-md",
                    can?(:insert_jobs, @access) &&
                      "text-gray-600 dark:text-gray-400 border-gray-300 dark:border-gray-700 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 focus-visible:border-blue-500 hover:text-blue-500 hover:border-blue-600 cursor-pointer",
                    not can?(:insert_jobs, @access) &&
                      "text-gray-400 dark:text-gray-500 border-gray-200 dark:border-gray-800 cursor-not-allowed opacity-50"
                  ]}
                >
                  <Icons.icon name="icon-plus-circle" class="mr-1 h-4 w-4" /> New
                </.link>
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

      <.live_component
        :if={@show_new_form}
        id="new-job-form"
        access={@access}
        conf={@conf}
        module={NewComponent}
        queues={@queues}
      />
    </div>
    """
  end

  attr :state, :string, required: true

  # Rows never show their own state because every page is filtered to one, so the heading
  # carries it in the state's hue where the sidebar would otherwise be the only clue.
  defp state_chip(assigns) do
    {_border, _background, text_class} = Colors.state_classes(assigns.state)

    assigns = assign(assigns, text_class: text_class)

    ~H"""
    <span
      id="jobs-state"
      class={["ml-2 flex items-center space-x-1.5 text-sm font-medium", @text_class]}
    >
      <span aria-hidden="true" class={["w-2 h-2 rounded-full", Colors.state_bg_class(@state)]}></span>
      <span>{@state}</span>
    </span>
    """
  end

  attr :count, :integer, required: true
  attr :limit, :any, required: true

  defp selection_count(assigns) do
    ~H"""
    <span
      id="selected-count"
      class="tabular text-sm font-semibold text-gray-700 dark:text-gray-300 whitespace-nowrap"
    >
      {integer_to_delimited(@count)} selected
    </span>

    <span
      :if={is_integer(@limit) and @count >= @limit}
      id="selected-limit"
      class="flex items-center space-x-1 rounded-md text-xs font-medium text-amber-700 dark:text-amber-400 whitespace-nowrap focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
      data-title={"Select all stops at #{integer_to_delimited(@limit)} jobs. Act on these, then select all again for the rest."}
      phx-hook="Tippy"
      tabindex="0"
    >
      <Icons.icon name="icon-exclamation-circle" class="w-4 h-4 text-amber-500 dark:text-amber-400" />
      <span>limit reached</span>
    </span>
    """
  end

  @keep_on_mount ~w(
    chunk_counts chunk_leader compensating_job default_params
    detailed jobs nodes params queues selected states
  )a

  @impl Page
  def handle_mount(socket) do
    default = fn ->
      %{limit: 20, sort_by: "time", sort_dir: "asc", state: "executing"}
    end

    assigns = Map.drop(socket.assigns, @keep_on_mount)

    %{socket | assigns: assigns}
    |> assign_new(:chunk_counts, fn -> %{} end)
    |> assign_new(:chunk_leader, fn -> nil end)
    |> assign_new(:compensating_job, fn -> nil end)
    |> assign_new(:default_params, default)
    |> assign_new(:detailed, fn -> nil end)
    |> assign_new(:diagnostics, fn -> nil end)
    |> assign_new(:diagnostics_at, fn -> nil end)
    |> assign_new(:history, fn -> [] end)
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

    detailed = JobQuery.refresh_job(conf, socket.assigns.detailed)

    history =
      if detailed do
        JobQuery.job_history(detailed, conf)
      else
        []
      end

    # Request fresh diagnostics if executing, but preserve existing data when job stops
    diagnostics =
      if detailed && detailed.state == "executing" do
        Oban.Notifier.notify(conf.name, :diagnostics, %{job_id: detailed.id})
        socket.assigns.diagnostics
      else
        socket.assigns.diagnostics
      end

    diagnostics_at = socket.assigns.diagnostics_at

    assign(socket,
      chunk_counts: chunk_counts(conf, detailed, socket),
      chunk_leader: chunk_leader(conf, detailed),
      compensating_job: compensating_job(conf, detailed),
      detailed: detailed,
      diagnostics: diagnostics,
      diagnostics_at: diagnostics_at,
      history: history,
      jobs: jobs,
      nodes: nodes(conf),
      os_time: System.os_time(:second),
      queues: queues(conf, socket.assigns.queues),
      selected: selected,
      states: states(conf, socket.assigns.states)
    )
  end

  @impl Page
  def handle_params(%{"id" => "new"} = params, _uri, socket) do
    params = params_with_defaults(params, socket)

    {:noreply,
     socket
     |> assign(detailed: nil, show_new_form: true, page_title: page_title("New Job"))
     |> assign(params: params)}
  end

  def handle_params(%{"id" => job_id} = params, _uri, socket) do
    params = params_with_defaults(params, socket)
    conf = socket.assigns.conf

    case JobQuery.refresh_job(conf, job_id) do
      nil ->
        {:noreply, push_patch(socket, to: oban_path(:jobs), replace: true)}

      job ->
        Oban.Notifier.listen(conf.name, [:diagnostics_reply])

        history = JobQuery.job_history(job, conf)

        {:noreply,
         socket
         |> assign(detailed: job, show_new_form: false, page_title: page_title(job))
         |> assign(chunk_counts: chunk_counts(conf, job, socket))
         |> assign(chunk_leader: chunk_leader(conf, job))
         |> assign(compensating_job: compensating_job(conf, job))
         |> assign(diagnostics: nil, diagnostics_at: nil)
         |> assign(history: history)
         |> assign(params: params)}
    end
  end

  def handle_params(params, _uri, socket) do
    %{conf: conf, resolver: resolver} = socket.assigns

    Oban.Notifier.unlisten(conf.name, [:diagnostics_reply])

    params = params_with_defaults(params, socket)

    selected =
      if same_scope?(socket.assigns.params, params) do
        socket.assigns.selected
      else
        MapSet.new()
      end

    socket =
      socket
      |> assign(detailed: nil, show_new_form: false, page_title: page_title("Jobs"))
      |> assign(diagnostics: nil, diagnostics_at: nil)
      |> assign(history: [])
      |> assign(params: params, selected: selected)
      |> assign(jobs: JobQuery.all_jobs(params, conf, resolver: resolver))
      |> assign(nodes: nodes(conf))
      |> assign(
        queues: queues(conf, socket.assigns.queues),
        states: states(conf, socket.assigns.states)
      )

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

    {:noreply, socket}
  end

  def handle_event("retry-jobs", _params, socket) do
    if can?(:retry_jobs, socket.assigns.access) do
      send(self(), :retry_selected)
    end

    {:noreply, socket}
  end

  def handle_event("delete-jobs", _params, socket) do
    if can?(:delete_jobs, socket.assigns.access) do
      send(self(), :delete_selected)
    end

    {:noreply, socket}
  end

  # System

  @impl Page
  def handle_info({ref, _val}, socket) when is_reference(ref) do
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, socket) do
    {:noreply, socket}
  end

  def handle_info({:flash, mode, message}, socket) do
    {:noreply, put_flash_with_clear(socket, mode, message)}
  end

  # Diagnostics

  def handle_info({:notification, :diagnostics_reply, %{"job_id" => job_id} = payload}, socket) do
    if socket.assigns.detailed && socket.assigns.detailed.id == job_id do
      {:noreply, assign(socket, diagnostics: payload, diagnostics_at: System.os_time(:second))}
    else
      {:noreply, socket}
    end
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

  def handle_info({:retry_job, job}, socket) do
    Telemetry.action(:retry_jobs, socket, [job_ids: [job.id]], fn ->
      JobQuery.retry_jobs(socket.assigns.conf, [job.id])
    end)

    job = %{job | state: "available", completed_at: nil, discarded_at: nil}

    {:noreply, assign(socket, detailed: job)}
  end

  def handle_info({:delete_job, job}, socket) do
    Telemetry.action(:delete_jobs, socket, [job_ids: [job.id]], fn ->
      JobQuery.delete_jobs(socket.assigns.conf, [job.id])
    end)

    {:noreply, push_patch(socket, to: oban_path(:jobs), replace: true)}
  end

  def handle_info({:update_job, job, changes}, socket) do
    conf = socket.assigns.conf

    case Oban.update_job(conf.name, job.id, changes) do
      {:ok, updated_job} ->
        socket =
          socket
          |> put_flash_with_clear(:info, "Job updated successfully")
          |> assign(detailed: updated_job)

        send_update(DetailComponent, id: "detail", reseed: true)

        {:noreply, socket}

      {:error, reason} ->
        send_update(DetailComponent, id: "detail", failure: reason)

        {:noreply, socket}
    end
  end

  # Bulk Actions

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
    %{conf: conf, jobs: jobs, params: params, resolver: resolver, selected: selected} =
      socket.assigns

    visible = MapSet.new(jobs, & &1.id)

    selected =
      case checked_mode(jobs, selected) do
        :all ->
          MapSet.new()

        :some ->
          MapSet.union(selected, visible)

        :none ->
          params
          |> JobQuery.all_job_ids(conf, resolver: resolver)
          |> MapSet.new()
          |> MapSet.union(visible)
      end

    {:noreply, assign(socket, selected: selected)}
  end

  # Param Helpers

  defp params_with_defaults(params, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params(JobQuery)

    Map.merge(socket.assigns.default_params, params)
  end

  # Socket Helpers

  defp hide_and_clear_selected(socket) do
    %{jobs: jobs, selected: selected} = socket.assigns

    jobs = for job <- jobs, do: Map.put(job, :hidden?, MapSet.member?(selected, job.id))

    assign(socket, jobs: jobs, selected: MapSet.new())
  end

  # Bulk Helpers

  defp bulk_limit(resolver, params) do
    state = String.to_existing_atom(params.state)

    Resolver.call_with_fallback(resolver, :bulk_action_limit, [state])
  end

  defp bulk_confirm(action, selected, params) do
    count = MapSet.size(selected)

    jobs =
      "#{integer_to_delimited(count)} #{params.state} #{if count == 1, do: "job", else: "jobs"}"

    scope =
      case Search.describe(params, JobQuery.qualifiers()) do
        [] -> ""
        filters -> " matching #{Enum.join(filters, " ")}"
      end

    case {action, params.state} do
      {:cancel, "executing"} ->
        "Cancel #{jobs}#{scope}? Running jobs are killed and marked cancelled."

      {:cancel, _state} ->
        "Cancel #{jobs}#{scope}? Cancelled jobs can be retried later."

      {:delete, _state} ->
        "Delete #{jobs}#{scope}? Deleted jobs can't be recovered."

      {:run, _state} ->
        "Run #{jobs}#{scope} now? They'll skip their scheduled time."

      {:retry, "completed"} ->
        "Run #{jobs}#{scope} again? Everything they did will happen again."

      {:retry, _state} ->
        "Retry #{jobs}#{scope}? They'll run again as soon as a queue picks them up."
    end
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

  defp states(conf, previous) do
    Metrics.state_counts(conf.name, @ordered_states, previous)
  end

  defp queues(conf, previous) do
    previous_counts = Metrics.extract_queue_counts(previous)
    counts = Metrics.all_queue_counts(conf.name, previous_counts)

    QueueQuery.all_queues(%{}, conf, counts)
  end

  defp compensating_job(conf, %Oban.Job{} = job) do
    WorkflowQuery.get_compensating_job(conf, job)
  end

  defp compensating_job(_conf, _job), do: nil

  defp chunk_leader(conf, %Oban.Job{} = job) do
    case chunk_leader_id(job) do
      nil -> nil
      leader_id -> JobQuery.refresh_job(conf, leader_id)
    end
  end

  defp chunk_leader(_conf, _job), do: nil

  # Members of a running chunk are all executing, so their count comes straight from the
  # leader's meta. Counting a finished chunk's members scans the leader's partition, so those
  # counts refresh when the leader changes state rather than on every tick.
  defp chunk_counts(conf, %Oban.Job{} = job, socket) do
    %{chunk_counts: previous_counts, detailed: previous} = socket.assigns

    cond do
      not chunk_leader?(job) ->
        %{}

      job.state == "executing" ->
        case chunk_count(job) do
          nil -> %{}
          count -> %{"executing" => count}
        end

      is_struct(previous) and previous.id == job.id and previous.state == job.state ->
        previous_counts

      true ->
        JobQuery.chunk_counts(conf, job)
    end
  end

  defp chunk_counts(_conf, _job, _socket), do: %{}
end
