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
        advisories: Form.advisories(assigns.form, assigns.baseline),
        changed?: assigns.form != assigns.baseline,
        defaults: worker_defaults(assigns.form.worker),
        editable?: assigns.cron.dynamic? and can?(:update_crons, assigns.access)
      )

    ~H"""
    <div id="cron-details">
      <.header access={@access} changed?={@changed?} cron={@cron} myself={@myself} />

      <div class="px-3 py-6">
        <div class="grid grid-cols-3 gap-6">
          <.history_chart changed?={@changed?} cron={@cron} />
          <.stats cron={@cron} />
        </div>

        <fieldset id="cron-form-fields" class="mt-6" disabled={not @editable?}>
          <form
            id="cron-form"
            class="bg-gray-50 dark:bg-gray-800 rounded-md p-4"
            phx-change="form-change"
            phx-submit="save-cron"
            phx-target={@myself}
          >
            <div class="grid grid-cols-2 gap-x-10 gap-y-6">
              <.schedule_panel form={@form} invalid={@invalid} timezones={@timezone_options} />
              <.job_panel defaults={@defaults} form={@form} invalid={@invalid} queues={@queues} />
            </div>

            <div
              :if={@editable? and @advisories != []}
              id="cron-form-advisories"
              class="mt-4 flex items-start gap-2 px-3 py-2 rounded-md bg-amber-50 dark:bg-amber-900/20 text-sm text-amber-800 dark:text-amber-300"
            >
              <Icons.icon name="icon-exclamation-circle" class="w-5 h-5 shrink-0" />
              <div class="space-y-1">
                <p :for={advisory <- @advisories}>{advisory}</p>
              </div>
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
              This cron is declared in your Oban config, so it can't be edited here.
              <a
                rel="static-blocker"
                href="https://oban.pro/docs/pro/Oban.Pro.Cron.html"
                target="_blank"
                class="inline-flex items-center gap-1 text-blue-500 hover:underline rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
              >
                Move it to Pro Cron
                <Icons.icon name="icon-arrow-top-right-on-square" class="w-3 h-3" />
              </a>
              to manage it from the dashboard.
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
                phx-disable-with="Saving…"
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
            <span class="font-normal text-gray-500 dark:text-gray-400">
              Cron<span :if={show_name?(@cron)}> ({@cron.name})</span>
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
          :if={not @cron.dynamic?}
          id="status-static"
          icon="command_line"
          label="Static"
          tooltip="Declared in your Oban config"
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
          confirm={"Delete the #{@cron.name} cron? Jobs it already inserted will still run."}
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

  attr :changed?, :boolean, default: false

  defp history_chart(assigns) do
    ~H"""
    <div id="cron-history" class="col-span-2">
      <div class="flex items-baseline">
        <h3 class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
          History
          <span
            id="cron-history-window"
            class="ml-1 normal-case font-normal text-gray-400 dark:text-gray-500 tabular"
          >
            {history_window(@cron.history)}
          </span>
        </h3>

        <.link
          id="cron-view-jobs"
          navigate={oban_path(:jobs, %{meta: [["cron_name"], @cron.name], state: jobs_state(@cron)})}
          data-confirm={@changed? && "Discard unsaved changes?"}
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
          Schedule
        </dt>
        <dd class="text-base text-gray-800 dark:text-gray-200">
          <code class="font-mono">{@cron.expression}</code>
          <span
            :if={CronExpr.describe(@cron.expression)}
            id="cron-expression-description"
            class="ml-1 text-gray-500 dark:text-gray-400"
          >
            ({CronExpr.describe(@cron.expression)})
          </span>
        </dd>
      </div>

      <div class="flex flex-col">
        <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
          Last Run
        </dt>
        <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
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
        <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
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
          <.state_icon state={@cron.last_state} />
          <span class="text-base text-gray-800 dark:text-gray-200">
            {state_label(@cron.last_state)}
          </span>
        </dd>
      </div>
    </dl>
    """
  end

  attr :form, :map, required: true

  attr :invalid, :list, default: []
  attr :timezones, :list, required: true

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
          invalid={:name in @invalid}
          hint="Changing the name resets this cron's history"
        />

        <.form_field
          label="Expression"
          name="expression"
          value={@form.expression}
          placeholder="* * * * *"
          required={true}
          invalid={:expression in @invalid}
          hint="Changing the schedule resets guaranteed insertion"
        />

        <.select_field
          label="Timezone"
          name="timezone"
          value={@form.timezone}
          options={[{"cron default", ""} | @timezones]}
          hint="Changing the timezone resets guaranteed insertion"
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

  attr :defaults, :map, required: true
  attr :invalid, :list, default: []

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
          invalid={:worker in @invalid}
        />

        <.select_field
          label="Queue"
          name="queue"
          value={@form.queue}
          options={queue_options(@queues, @form.queue, @defaults.queue)}
        />

        <div class="grid grid-cols-2 gap-4">
          <.form_field
            label="Priority"
            name="priority"
            value={@form.priority}
            type="number"
            min={0}
            max={9}
            placeholder={@defaults.priority}
          />

          <.form_field
            label="Max Attempts"
            name="max_attempts"
            value={@form.max_attempts}
            type="number"
            min={1}
            placeholder={@defaults.max_attempts}
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
          invalid={:args in @invalid}
          rows={2}
          hint="A JSON object passed to every job"
        />
      </div>
    </div>
    """
  end

  # A blank timezone defers to Pro Cron's configured timezone, and a blank queue to the worker's
  # queue.
  defp queue_options(queues, current, default) do
    label = if default, do: "worker default (#{default})", else: "worker default"

    [{label, ""} | queue_options(queues, current)]
  end

  # Placeholders show what the worker itself would use, so leaving a field blank isn't a guess.
  # Workers from other languages or apps aren't loaded here, and then there's nothing to claim.
  defp worker_defaults(worker) do
    case Oban.Worker.from_string(worker) do
      {:ok, module} ->
        opts = module.__opts__()

        %{
          max_attempts: to_string(Keyword.get(opts, :max_attempts, 20)),
          priority: to_string(Keyword.get(opts, :priority, 0)),
          queue: to_string(Keyword.get(opts, :queue, :default))
        }

      {:error, _reason} ->
        %{max_attempts: "worker default", priority: "worker default", queue: nil}
    end
  end

  defp history_window([]), do: "no runs yet"
  defp history_window([_job]), do: "last run"
  defp history_window(jobs), do: "last #{length(jobs)} runs"

  # Callbacks

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    chart_data = Enum.map(assigns.history, &chart_point/1)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:errors, fn -> [] end)
      |> assign_new(:invalid, fn -> [] end)
      |> assign_new(:timezone_options, fn -> Timezones.options_with_offsets() end)
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

    verb = if cron.paused?, do: "resume", else: "pause"

    case Cron.update(conf.name, cron.name, paused: not cron.paused?) do
      {:ok, entry} ->
        send(self(), :refresh)
        send(self(), {:flash, :info, "#{String.capitalize(verb)}d cron #{cron.name}"})

        {:noreply, assign(socket, cron: %{cron | paused?: entry.paused})}

      {:error, _reason} ->
        send(self(), {:flash, :error, "Failed to #{verb} cron #{cron.name}"})

        {:noreply, socket}
    end
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

        {:noreply, assign(socket, baseline: form, errors: [], invalid: [], seeded: nil)}
      else
        {:noreply, push_patch(socket, to: oban_path([:crons, entry.name], page_params))}
      end
    else
      {:error, reason} ->
        {:noreply,
         assign(socket, errors: Form.format_failure(reason), invalid: Form.invalid_fields(reason))}
    end
  end

  # Helpers

  defp assign_seed(socket, cron) do
    form = Form.seed(cron)

    assign(socket, baseline: form, errors: [], form: form, invalid: [], seeded: cron.name)
  end

  # The jobs page needs a state to filter on, and the cron's own last state is the one worth
  # looking at. Without any runs there is nothing to show but the default.
  defp jobs_state(%{last_state: state}) when is_binary(state), do: state
  defp jobs_state(_cron), do: "completed"

  defp state_label(nil), do: "Unknown"
  defp state_label(state), do: String.capitalize(state)
end
