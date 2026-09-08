defmodule Oban.Web.JobsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Met

  alias Oban.Web.{Colors, JobQuery, Metrics, Page, QueueQuery, Resolver}
  alias Oban.Web.{Search, SearchComponent, SortComponent, Telemetry, Utils, WorkflowQuery}

  alias Oban.Web.Jobs.{ChartComponent, DetailComponent, NewComponent}
  alias Oban.Web.Jobs.{SidebarComponent, TableComponent}

  @known_params JobQuery.known_params() ++ ~w(limit sort_by sort_dir)
  @ordered_states ~w(executing available suspended scheduled retryable cancelled discarded completed)
  @archive_states JobQuery.archive_states()

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
        archive?={@archive?}
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
          :if={is_nil(@detailed) and not @archive?}
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
          <%= cond do %>
            <% @archive? and not @pro_available? -> %>
              <Core.pro_promo feature="Archived jobs" icon="icon-square-stack">
                Pruner rules can archive finished jobs instead of deleting them, keeping a record
                of what ran without slowing down the jobs table. Archived jobs are browsed and
                searched here, just like live ones.
              </Core.pro_promo>
            <% @archive? and not @archive_available? -> %>
              <Core.migration_prompt
                id="archive-migration-prompt"
                conf={@conf}
                docs="https://oban.pro/docs/pro/Oban.Pro.Pruner.html#archiving-jobs"
                feature="Archived jobs"
                table="oban_jobs_archive"
                version="v1.8"
              />
            <% @detailed -> %>
              <.live_component
                id="detail"
                access={@access}
                archive?={@archive?}
                conf={@conf}
                diagnostics={@diagnostics}
                diagnostics_at={@diagnostics_at}
                history={@history}
                init_state={@init_state}
                chunk_counts={@chunk_counts}
                chunk_leader={@chunk_leader}
                compensating_job={@compensating_job}
                neighbors={@neighbors}
                job={@detailed}
                module={DetailComponent}
                os_time={@os_time}
                params={without_defaults(Map.delete(@params, "id"), @default_params)}
                queues={@queues}
                resolver={@resolver}
              />
            <% true -> %>
              <div class="sticky top-0 z-20 flex items-start pr-3 py-3 rounded-t-md bg-white dark:bg-gray-900 border-b border-gray-200 dark:border-gray-700">
                <div id="jobs-header" class="h-10 pr-12 flex-none flex items-center">
                  <Core.all_checkbox
                    click="toggle-select-all"
                    checked={checked_mode(@jobs, @selected)}
                    myself={@myself}
                  />

                  <h2 class="flex items-center text-base font-semibold dark:text-gray-200">
                    <span :if={@archive?} id="jobs-source" class="flex items-center">
                      <Icons.icon name="icon-square-stack" class="w-5 h-5 mr-1.5 text-violet-500" />
                      Archived
                    </span>
                    <span :if={not @archive?} id="jobs-source">Jobs</span>
                    <.state_chip state={@params.state} />
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
                      :if={not @archive? and cancelable?(@jobs, @access)}
                      label="Cancel"
                      click="cancel-jobs"
                      confirm={bulk_confirm(:cancel, @selected, @params)}
                      target={@myself}
                    >
                      <:icon><Icons.icon name="icon-x-circle" class="w-5 h-5" /></:icon>
                      <:title>Cancel Jobs</:title>
                    </Core.action_button>

                    <Core.action_button
                      :if={not @archive? and retryable?(@jobs, @access)}
                      label="Retry"
                      click="retry-jobs"
                      confirm={bulk_confirm(:retry, @selected, @params)}
                      target={@myself}
                    >
                      <:icon><Icons.icon name="icon-arrow-right-circle" class="w-5 h-5" /></:icon>
                      <:title>Retry Jobs</:title>
                    </Core.action_button>

                    <Core.action_button
                      :if={not @archive? and runnable?(@jobs, @access)}
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
                    :if={Enum.empty?(@selected) and not @archive?}
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
    archive? chunk_counts chunk_leader compensating_job default_params
    detailed jobs neighbors nodes params queues selected states
  )a

  @impl Page
  def handle_mount(socket) do
    default = fn ->
      %{limit: 20, sort_by: "time", sort_dir: "asc", state: "executing"}
    end

    assigns = Map.drop(socket.assigns, @keep_on_mount)

    %{socket | assigns: assigns}
    |> assign(:archive_available?, Utils.has_archive?(socket.assigns.conf))
    |> assign(:pro_available?, Utils.has_pro?())
    |> assign_new(:archive?, fn -> false end)
    |> assign_new(:chunk_counts, fn -> %{} end)
    |> assign_new(:chunk_leader, fn -> nil end)
    |> assign_new(:compensating_job, fn -> nil end)
    |> assign_new(:default_params, default)
    |> assign_new(:detailed, fn -> nil end)
    |> assign_new(:diagnostics, fn -> nil end)
    |> assign_new(:diagnostics_at, fn -> nil end)
    |> assign_new(:history, fn -> [] end)
    |> assign_new(:jobs, fn -> [] end)
    |> assign_new(:neighbors, fn -> %{} end)
    |> assign_new(:nodes, fn -> [] end)
    |> assign_new(:os_time, fn -> System.os_time(:millisecond) end)
    |> assign_new(:params, default)
    |> assign_new(:queues, fn -> [] end)
    |> assign_new(:selected, &MapSet.new/0)
    |> assign_new(:states, fn -> [] end)
  end

  @impl Page
  def handle_refresh(socket) do
    %{conf: conf, params: params, resolver: resolver} = socket.assigns

    query_opts = query_opts(params)
    jobs = all_jobs(socket, params, resolver: resolver)

    selected =
      if Enum.any?(socket.assigns.selected) do
        all_job_ids = JobQuery.all_job_ids(params, conf, resolver: resolver)

        all_job_ids
        |> MapSet.new()
        |> MapSet.intersection(socket.assigns.selected)
      else
        MapSet.new()
      end

    detailed = JobQuery.refresh_job(conf, socket.assigns.detailed, query_opts)

    history =
      if detailed do
        JobQuery.job_history(detailed, conf, query_opts)
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
      chunk_leader: chunk_leader(conf, detailed, query_opts),
      compensating_job: compensating_job(conf, detailed),
      detailed: detailed,
      diagnostics: diagnostics,
      diagnostics_at: diagnostics_at,
      history: history,
      jobs: jobs,
      neighbors: neighbors(conf, detailed, query_opts),
      nodes: nodes(conf),
      os_time: System.os_time(:millisecond),
      queues: queues(conf, socket.assigns.queues),
      selected: selected,
      states: states(conf, socket.assigns.states, params)
    )
  end

  @impl Page
  def handle_params(%{"id" => "new"} = params, _uri, socket) do
    params = params_with_defaults(params, socket)

    {:noreply,
     socket
     |> assign(detailed: nil, show_new_form: true, page_title: page_title("New Job"))
     |> assign_params(params)}
  end

  def handle_params(%{"id" => job_id} = params, _uri, socket) do
    params = params_with_defaults(params, socket)
    conf = socket.assigns.conf
    query_opts = query_opts(params)

    job = if archive_ready?(socket, params), do: JobQuery.refresh_job(conf, job_id, query_opts)

    case job do
      nil ->
        path = oban_path(:jobs, list_params(%{}, JobQuery.archived?(params)))

        {:noreply, push_patch(socket, to: path, replace: true)}

      job ->
        Oban.Notifier.listen(conf.name, [:diagnostics_reply])

        history = JobQuery.job_history(job, conf, query_opts)
        socket = assign_params(socket, params)

        {:noreply,
         socket
         |> assign(detailed: job, show_new_form: false, page_title: detail_title(job, params))
         |> assign(chunk_counts: chunk_counts(conf, job, socket))
         |> assign(chunk_leader: chunk_leader(conf, job, query_opts))
         |> assign(compensating_job: compensating_job(conf, job))
         |> assign(neighbors: neighbors(conf, job, query_opts))
         |> assign(diagnostics: nil, diagnostics_at: nil)
         |> assign(history: history)}
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

    title = if JobQuery.archived?(params), do: "Archived", else: "Jobs"

    socket =
      socket
      |> assign(detailed: nil, show_new_form: false, page_title: page_title(title))
      |> assign(diagnostics: nil, diagnostics_at: nil)
      |> assign(history: [])
      |> assign_params(params)
      |> assign(selected: selected)
      |> assign(jobs: all_jobs(socket, params, resolver: resolver))
      |> assign(nodes: nodes(conf))
      |> assign(
        queues: queues(conf, socket.assigns.queues),
        states: states(conf, socket.assigns.states, params)
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
    %{archive?: archive?, conf: conf} = socket.assigns

    Telemetry.action(:delete_jobs, socket, [job_ids: [job.id]], fn ->
      JobQuery.delete_jobs(conf, [job.id], archive: archive?)
    end)

    path = oban_path(:jobs, list_params(%{}, archive?))

    {:noreply, push_patch(socket, to: path, replace: true)}
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
      JobQuery.delete_jobs(socket.assigns.conf, job_ids, archive: socket.assigns.archive?)
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

  # Only finished jobs are archived, so the archive opens on completed jobs unless the state is
  # already one that exists there.
  defp params_with_defaults(params, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params(JobQuery)

    params = Map.merge(socket.assigns.default_params, params)

    if JobQuery.archived?(params) and params.state not in @archive_states do
      %{params | state: "completed"}
    else
      params
    end
  end

  # The archive only changes when the pruner runs, so watching it doesn't need a refresh timer.
  # Pausing goes through the dashboard, which restores the rate when the archive is left.
  defp assign_params(socket, params) do
    was_archived? = socket.assigns.archive?
    now_archived? = JobQuery.archived?(params)

    cond do
      now_archived? and not was_archived? -> send(self(), :pause_refresh)
      was_archived? and not now_archived? -> send(self(), :resume_refresh)
      true -> :ok
    end

    assign(socket, archive?: now_archived?, params: params)
  end

  defp query_opts(params), do: [archive: JobQuery.archived?(params)]

  defp detail_title(job, params) do
    if JobQuery.archived?(params) do
      page_title("#{job.worker} Archived Job (#{job.id})")
    else
      page_title(job)
    end
  end

  # Without Pro or its v1.8 migration there's no archive table to query, so the page explains
  # what's missing instead of showing an empty list.
  defp archive_ready?(socket, params) do
    not JobQuery.archived?(params) or socket.assigns.archive_available?
  end

  defp all_jobs(socket, params, opts) do
    if archive_ready?(socket, params) do
      JobQuery.all_jobs(params, socket.assigns.conf, opts)
    else
      []
    end
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
    archived = if JobQuery.archived?(params), do: "archived ", else: ""

    jobs =
      "#{integer_to_delimited(count)} #{archived}#{params.state} #{if count == 1, do: "job", else: "jobs"}"

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

  # Counting the archive would scan an unindexed table on every refresh, and the pruner only adds
  # to it occasionally, so archived states are listed without counts.
  defp states(conf, previous, params) do
    if JobQuery.archived?(params) do
      for state <- @archive_states, do: %{name: state, count: nil}
    else
      Metrics.state_counts(conf.name, @ordered_states, previous)
    end
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

  defp neighbors(conf, %Oban.Job{} = job, query_opts) do
    for {kind, id_fun} <- [chain: &chain_id/1, backfill: &backfill_id/1],
        is_binary(id_fun.(job)),
        into: %{} do
      {kind, JobQuery.neighbors(conf, job, kind, query_opts)}
    end
  end

  defp neighbors(_conf, _job, _query_opts), do: %{}

  defp chunk_leader(conf, %Oban.Job{} = job, query_opts) do
    case chunk_leader_id(job) do
      nil -> nil
      leader_id -> JobQuery.refresh_job(conf, leader_id, query_opts)
    end
  end

  defp chunk_leader(_conf, _job, _query_opts), do: nil

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
        JobQuery.chunk_counts(conf, job, query_opts(socket.assigns.params))
    end
  end

  defp chunk_counts(_conf, _job, _socket), do: %{}
end
