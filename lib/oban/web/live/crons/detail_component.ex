defmodule Oban.Web.Crons.DetailComponent do
  use Oban.Web, :live_component

  import Oban.Web.Crons.Helpers, only: [state_icon: 1, maybe_to_unix: 1, show_name?: 1]
  import Oban.Web.FormComponents

  alias Oban.Pro.Cron
  alias Oban.Web.{CronExpr, Timezones}
  alias Oban.Web.Crons.Form

  @compile {:no_warn_undefined, Cron}

  @impl Phoenix.LiveComponent
  def render(assigns) do
    assigns =
      assign(assigns,
        changed?: assigns.form != assigns.baseline,
        editable?: assigns.cron.dynamic? and can?(:update_crons, assigns.access)
      )

    ~H"""
    <div id="cron-details">
      <.header access={@access} changed?={@changed?} cron={@cron} myself={@myself} />

      <div class="px-3 py-6">
        <div class="grid grid-cols-3 gap-6">
          <.history_chart cron={@cron} />
          <.stats cron={@cron} />
        </div>

        <fieldset id="cron-form-fields" class="mt-6" disabled={not @editable?}>
          <form id="cron-form" phx-change="form-change" phx-submit="save-cron" phx-target={@myself}>
            <div class="grid grid-cols-2 gap-x-10 gap-y-6">
              <.schedule_panel form={@form} />
              <.job_panel form={@form} queues={@queues} />
            </div>

            <div
              :if={@errors != []}
              id="cron-form-errors"
              role="alert"
              class="mt-4 px-3 py-2 rounded-md bg-red-50 dark:bg-red-900/20 text-sm text-red-700 dark:text-red-300 space-y-1"
            >
              <p :for={error <- @errors}>{error}</p>
            </div>

            <p
              :if={not @cron.dynamic?}
              id="cron-static-note"
              class="mt-6 text-sm text-gray-500 dark:text-gray-400"
            >
              This cron is declared in your Oban configuration, so it can't be edited here.
              <a
                rel="static-blocker"
                href="https://oban.pro/docs/pro/Oban.Pro.Cron.html"
                target="_blank"
                class="inline-flex items-center gap-1 text-blue-500 hover:underline rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
              >
                Editing requires Pro Cron
                <Icons.icon name="icon-arrow-top-right-on-square" class="w-3 h-3" />
              </a>
            </p>

            <div :if={@editable?} class="mt-6 flex justify-end items-center gap-4">
              <button
                type="button"
                id="detail-discard"
                disabled={not @changed?}
                phx-click="discard-changes"
                phx-target={@myself}
                class="text-sm font-medium text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Discard
              </button>
              <button
                type="submit"
                id="detail-save"
                disabled={not @changed?}
                class="px-6 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-900 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Save Changes
              </button>
            </div>
          </form>
        </fieldset>
      </div>
    </div>
    """
  end

  attr :access, :any, required: true
  attr :changed?, :boolean, required: true
  attr :cron, :any, required: true
  attr :myself, :any, required: true

  defp header(assigns) do
    ~H"""
    <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
      <h2 class="min-w-0">
        <button
          id="back-link"
          class="flex items-center min-w-0 max-w-full hover:text-blue-500 cursor-pointer bg-transparent border-0 p-0 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
          data-confirm-back={@changed? && "Discard unsaved changes?"}
          data-escape-back={true}
          phx-hook="HistoryBack"
          type="button"
        >
          <Icons.icon name="icon-arrow-left" class="w-5 h-5 shrink-0" />
          <span class="text-lg font-bold ml-2 truncate">
            {@cron.worker}
            <span :if={show_name?(@cron)} class="font-normal text-gray-500 dark:text-gray-400">
              ({@cron.name})
            </span>
          </span>
        </button>
      </h2>

      <div class="flex items-center space-x-3">
        <Core.status_badge
          :if={@cron.dynamic?}
          id="status-dynamic"
          icon="sparkles"
          label="Dynamic"
        />
        <Core.status_badge
          :if={@cron.paused?}
          id="status-paused"
          icon="pause_circle"
          label="Paused"
        />

        <Core.icon_button
          id="run-now-button"
          icon="play_circle"
          label="Run Now"
          color="blue"
          tooltip="Insert a job for this cron immediately"
          disabled={not can?(:insert_jobs, @access)}
          phx-click="run-now"
          phx-target={@myself}
        />

        <Core.icon_button
          id="toggle-pause-button"
          icon={if @cron.paused?, do: "play_circle", else: "pause_circle"}
          label={if @cron.paused?, do: "Resume", else: "Pause"}
          color="yellow"
          tooltip={pause_tooltip(@cron)}
          disabled={not @cron.dynamic? or not can?(:pause_crons, @access)}
          phx-click="toggle-pause"
          phx-target={@myself}
        />

        <Core.icon_button
          id="delete-cron-button"
          icon="trash"
          label="Delete"
          color="red"
          tooltip={
            if @cron.dynamic?,
              do: "Delete this cron",
              else: "Only dynamic crons can be deleted"
          }
          disabled={not @cron.dynamic? or not can?(:delete_crons, @access)}
          confirm="Are you sure you want to delete this cron?"
          phx-click="delete-cron"
          phx-target={@myself}
        />
      </div>
    </div>
    """
  end

  defp pause_tooltip(%{dynamic?: false}), do: "Only dynamic crons can be paused"
  defp pause_tooltip(%{paused?: true}), do: "Resume scheduling jobs"
  defp pause_tooltip(_cron), do: "Pause scheduling jobs"

  attr :cron, :any, required: true

  defp history_chart(assigns) do
    ~H"""
    <div id="cron-history" class="col-span-2">
      <div class="flex items-baseline">
        <h3 class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
          History
        </h3>

        <.link
          id="cron-view-jobs"
          navigate={oban_path(:jobs, %{meta: [["cron_name"], @cron.name], state: "completed"})}
          class="ml-auto flex items-center gap-1 text-xs font-medium text-gray-500 dark:text-gray-400 hover:text-blue-500 dark:hover:text-blue-400 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
        >
          View all jobs <Icons.icon name="icon-arrow-right" class="w-3 h-3" />
        </.link>
      </div>

      <div
        id="cron-chart"
        class="mt-2 h-48 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
        phx-hook="CronChart"
        phx-update="ignore"
      >
      </div>
    </div>
    """
  end

  attr :cron, :any, required: true

  defp stats(assigns) do
    ~H"""
    <dl class="col-span-1 space-y-4">
      <div class="flex flex-col">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Last Run
        </dt>
        <dd class="text-base text-gray-800 dark:text-gray-200">
          <span
            id="cron-last-time"
            data-timestamp={maybe_to_unix(@cron.last_at)}
            phx-hook="Relativize"
            phx-update="ignore"
          >
            -
          </span>
        </dd>
      </div>

      <div class="flex flex-col">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Next Run
        </dt>
        <dd class="text-base text-gray-800 dark:text-gray-200">
          <span
            id="cron-next-time"
            data-timestamp={maybe_to_unix(@cron.next_at)}
            phx-hook="Relativize"
            phx-update="ignore"
          >
            -
          </span>
        </dd>
      </div>

      <div class="flex flex-col">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Last Status
        </dt>
        <dd class="flex items-center space-x-1">
          <.state_icon state={@cron.last_state} paused={@cron.paused?} />
          <span class="text-base text-gray-800 dark:text-gray-200">
            {if @cron.paused?, do: "Paused", else: state_label(@cron.last_state)}
          </span>
        </dd>
      </div>
    </dl>
    """
  end

  attr :form, :map, required: true

  defp schedule_panel(assigns) do
    ~H"""
    <div id="cron-schedule">
      <h3 class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
        Schedule
      </h3>

      <div class="mt-3 space-y-4">
        <.form_field
          label="Name"
          name="name"
          value={@form.name}
          required={true}
          hint="Changing the name resets this cron's history"
        />

        <div>
          <.form_field
            label="Expression"
            name="expression"
            value={@form.expression}
            placeholder="* * * * *"
            required={true}
          />

          <p
            :if={CronExpr.describe(@form.expression)}
            id="cron-expression-description"
            class="mt-1.5 text-xs text-gray-500 dark:text-gray-400"
          >
            {CronExpr.describe(@form.expression)}
          </p>
        </div>

        <.select_field
          label="Timezone"
          name="timezone"
          value={@form.timezone}
          options={timezone_options()}
        />

        <.checkbox_field
          label="Guaranteed"
          name="guaranteed"
          checked={@form.guaranteed}
          hint="Insert a job even when the scheduled time was missed"
        />
      </div>
    </div>
    """
  end

  attr :form, :map, required: true
  attr :queues, :list, required: true

  defp job_panel(assigns) do
    ~H"""
    <div id="cron-job">
      <h3 class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
        Job
      </h3>

      <div class="mt-3 space-y-4">
        <.form_field
          label="Worker"
          name="worker"
          value={@form.worker}
          placeholder="MyApp.Workers.SomeWorker"
          required={true}
        />

        <.select_field
          label="Queue"
          name="queue"
          value={@form.queue}
          options={queue_options(@queues, @form.queue)}
        />

        <div class="grid grid-cols-2 gap-4">
          <.form_field
            label="Priority"
            name="priority"
            value={@form.priority}
            type="number"
            min={0}
            max={9}
            placeholder="0"
          />

          <.form_field
            label="Max Attempts"
            name="max_attempts"
            value={@form.max_attempts}
            type="number"
            min={1}
            placeholder="20"
          />
        </div>

        <.form_field
          label="Tags"
          name="tags"
          value={@form.tags}
          placeholder="tag1, tag2"
          hint="Comma separated"
        />

        <.form_field
          label="Args"
          name="args"
          value={@form.args}
          type="textarea"
          placeholder="{}"
          rows={2}
          hint="A JSON object passed to every job"
        />
      </div>
    </div>
    """
  end

  # A blank timezone defers to the plugin's timezone, and a blank queue to the worker's queue. A
  # queue that isn't running still has to appear as an option, otherwise the browser selects the
  # first option and a save would silently change it.
  defp timezone_options, do: [{"plugin default", ""} | Timezones.options()]

  defp queue_options(queues, current) do
    options = queue_options(queues)

    options =
      if current == "" or Enum.any?(options, &(elem(&1, 1) == current)) do
        options
      else
        [{current, current} | options]
      end

    [{"worker default", ""} | options]
  end

  # Callbacks

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    chart_data = Enum.map(assigns.history, &chart_point/1)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:errors, fn -> [] end)
      |> push_event("cron-history", %{history: chart_data})

    # Refreshes replace the cron every second. Freshness is per field: an untouched field tracks
    # the live cron, while a field with edits in progress keeps them.
    if Map.get(socket.assigns, :seeded) == assigns.cron.name do
      fresh = Form.seed(assigns.cron)
      %{baseline: baseline, form: form} = socket.assigns

      {:ok, assign(socket, baseline: fresh, form: merge_fresh(form, baseline, fresh))}
    else
      {:ok, assign_seed(socket, assigns.cron)}
    end
  end

  defp chart_point(job) do
    timestamp =
      (job.finished_at || job.attempted_at || job.scheduled_at)
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix(:millisecond)

    duration =
      case {job.attempted_at, job.finished_at} do
        {nil, _} ->
          0

        {attempted_at, nil} ->
          NaiveDateTime.diff(NaiveDateTime.utc_now(), attempted_at, :millisecond)

        {attempted_at, finished_at} ->
          NaiveDateTime.diff(finished_at, attempted_at, :millisecond)
      end

    %{timestamp: timestamp, duration: duration, state: job.state}
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("run-now", _params, socket) do
    enforce_access!(:insert_jobs, socket.assigns.access)

    %{cron: cron, conf: conf} = socket.assigns

    args = Map.get(cron.opts, "args", %{})

    opts =
      cron.opts
      |> Map.take(~w(max_attempts priority queue tags))
      |> Keyword.new(fn {key, val} -> {String.to_existing_atom(key), val} end)
      |> Keyword.put(:meta, %{cron: true, cron_expr: cron.expression, cron_name: cron.name})

    changeset = build_changeset(cron.worker, args, opts)

    case Oban.insert(conf.name, changeset) do
      {:ok, _job} ->
        send(self(), :refresh)
        send(self(), {:flash, :info, "Job inserted for #{cron.worker}"})

      {:error, _reason} ->
        send(self(), {:flash, :error, "Failed to insert job"})
    end

    {:noreply, socket}
  end

  def handle_event("toggle-pause", _params, socket) do
    enforce_access!(:pause_crons, socket.assigns.access)

    %{cron: cron, conf: conf} = socket.assigns

    paused? = not cron.paused?

    Cron.update(conf.name, cron.name, paused: paused?)

    {:noreply, assign(socket, cron: %{cron | paused?: paused?})}
  end

  def handle_event("delete-cron", _params, socket) do
    enforce_access!(:delete_crons, socket.assigns.access)

    %{cron: cron, conf: conf, params: params} = socket.assigns

    case Cron.delete(conf.name, cron.name) do
      {:ok, _deleted} ->
        send(self(), {:flash, :info, "Deleted cron #{cron.name}"})
        {:noreply, push_patch(socket, to: oban_path(:crons, params))}

      {:error, _reason} ->
        send(self(), {:flash, :error, "Failed to delete cron"})
        {:noreply, socket}
    end
  end

  def handle_event("form-change", params, socket) do
    form = Map.merge(socket.assigns.form, Form.cast_params(params))

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("discard-changes", _params, socket) do
    {:noreply, assign_seed(socket, socket.assigns.cron)}
  end

  def handle_event("save-cron", params, socket) do
    enforce_access!(:update_crons, socket.assigns.access)

    %{baseline: baseline, conf: conf, cron: cron, params: page_params} = socket.assigns

    form = Map.merge(socket.assigns.form, Form.cast_params(params))
    socket = assign(socket, form: form)

    with {:ok, opts} <- Form.build_opts(form, baseline, cron.opts),
         {:ok, entry} <- Cron.update(conf.name, cron.name, opts) do
      send(self(), {:flash, :info, "Cron \"#{entry.name}\" updated"})

      # The page reloads the cron by name, so a renamed entry has to be reopened at its new
      # address. Either way the form reseeds from what was stored.
      if entry.name == cron.name do
        send(self(), :refresh)

        {:noreply, assign(socket, baseline: form, errors: [], seeded: nil)}
      else
        {:noreply, push_patch(socket, to: oban_path([:crons, entry.name], page_params))}
      end
    else
      {:error, reason} ->
        {:noreply, assign(socket, errors: Form.format_failure(reason))}
    end
  end

  # Helpers

  defp assign_seed(socket, cron) do
    form = Form.seed(cron)

    assign(socket, baseline: form, errors: [], form: form, seeded: cron.name)
  end

  defp merge_fresh(form, baseline, fresh) do
    Map.new(fresh, fn {key, fresh_value} ->
      form_value = Map.fetch!(form, key)

      if form_value == Map.fetch!(baseline, key) do
        {key, fresh_value}
      else
        {key, form_value}
      end
    end)
  end

  defp state_label(nil), do: "Unknown"
  defp state_label(state), do: String.capitalize(state)
end
