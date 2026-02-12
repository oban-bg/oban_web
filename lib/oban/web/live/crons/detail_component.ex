defmodule Oban.Web.Crons.DetailComponent do
  use Oban.Web, :live_component

  import Oban.Web.Crons.Helpers
  import Oban.Web.FormComponents

  alias Oban.Pro.Plugins.DynamicCron
  alias Oban.Web.{CronExpr, Timezones}

  @compile {:no_warn_undefined, DynamicCron}

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="cron-details" phx-window-keydown="keydown" phx-target={@myself}>
      <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
        <.link
          patch={oban_path(:crons, @params)}
          id="back-link"
          class="flex items-center hover:text-blue-500"
          data-title="Back to crons"
          phx-hook="Tippy"
        >
          <Icons.arrow_left class="w-5 h-5" />
          <span class="text-lg font-bold ml-2">{@cron.worker}</span>
        </.link>

        <div class="flex space-x-3">
          <div :if={@cron.dynamic?} class="flex items-center">
            <span class="inline-flex items-center px-4 py-2 border border-transparent rounded-md text-sm font-medium bg-violet-100 text-violet-700 dark:bg-violet-700/70 dark:text-violet-200">
              <Icons.sparkles class="mr-1 h-4 w-4" /> Dynamic
            </span>
          </div>

          <button
            :if={can?(:insert_jobs, @access)}
            type="button"
            id="run-now-button"
            data-title="Insert a job for this cron immediately"
            phx-hook="Tippy"
            class="flex items-center text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 focus-visible:border-blue-500 hover:text-blue-500 hover:border-blue-600 cursor-pointer"
            phx-click="run-now"
            phx-target={@myself}
          >
            <Icons.play_circle class="mr-2 h-5 w-5" /> Run Now
          </button>

          <button
            :if={@cron.dynamic? and can?(:pause_queues, @access)}
            type="button"
            id="toggle-pause-button"
            data-title={if @cron.paused?, do: "Resume scheduling jobs", else: "Pause scheduling jobs"}
            phx-hook="Tippy"
            class="flex items-center text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 focus-visible:border-blue-500 hover:text-blue-500 hover:border-blue-600 cursor-pointer"
            phx-click="toggle-pause"
            phx-target={@myself}
          >
            <%= if @cron.paused? do %>
              <Icons.play_circle class="mr-2 h-5 w-5" /> Resume
            <% else %>
              <Icons.pause_circle class="mr-2 h-5 w-5" /> Pause
            <% end %>
          </button>

          <button
            :if={@cron.dynamic? and can?(:delete_jobs, @access)}
            type="button"
            id="delete-cron-button"
            data-title="Delete this dynamic cron"
            phx-hook="Tippy"
            class="flex items-center text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-rose-500 focus-visible:border-rose-500 hover:text-rose-600 hover:border-rose-500 cursor-pointer"
            phx-click="delete-cron"
            phx-target={@myself}
            data-confirm="Are you sure you want to delete this cron?"
          >
            <Icons.trash class="mr-2 h-5 w-5" /> Delete
          </button>
        </div>
      </div>

      <div class="grid grid-cols-3 gap-6 px-3 py-6">
        <div class="col-span-2">
          <.history_chart cron={@cron} />
        </div>

        <div class="col-span-1">
          <div class="flex justify-between mb-6 pr-6">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Last Run
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                <span
                  id="cron-last-time"
                  data-timestamp={maybe_to_unix(@cron.last_at)}
                  phx-hook="Relativize"
                  phx-update="ignore"
                >
                  -
                </span>
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Next Run
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                <span
                  id="cron-next-time"
                  data-timestamp={maybe_to_unix(@cron.next_at)}
                  phx-hook="Relativize"
                  phx-update="ignore"
                >
                  -
                </span>
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Last Status
              </span>
              <div class="flex items-center space-x-1">
                <.state_icon state={@cron.last_state} paused={@cron.paused?} />
                <span class="text-base text-gray-800 dark:text-gray-200">
                  {if @cron.paused?, do: "Paused", else: state_label(@cron.last_state)}
                </span>
              </div>
            </div>
          </div>

          <div class="flex flex-col">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
              Schedule
            </span>
            <span class="text-base text-gray-800 dark:text-gray-200">
              <code class="font-mono">{@cron.expression}</code>
              <span
                :if={CronExpr.describe(@cron.expression)}
                class="ml-2 text-gray-500 dark:text-gray-400"
              >
                ({CronExpr.describe(@cron.expression)})
              </span>
            </span>
          </div>
        </div>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
          <Icons.pencil_square />
          <span>Edit Configuration</span>
        </h3>

        <fieldset disabled={not @cron.dynamic?}>
          <form
            id="cron-form"
            class="grid grid-cols-4 gap-4 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
            phx-change="form-change"
            phx-submit="save-cron"
            phx-target={@myself}
          >
            <.form_field label="Schedule" name="expression" value={@cron.expression} />

            <.form_field label="Worker" name="worker" value={@cron.worker} />

            <.select_field
              label="Queue"
              name="queue"
              value={get_opt(@cron, "queue") || "default"}
              options={queue_options(@queues)}
            />

            <.select_field
              label="Timezone"
              name="timezone"
              value={get_opt(@cron, "timezone") || "Etc/UTC"}
              options={Timezones.options_with_blank()}
            />

            <div class="grid grid-cols-2 gap-2">
              <.form_field
                label="Priority"
                name="priority"
                value={get_opt(@cron, "priority")}
                type="number"
                placeholder="0"
              />

              <.form_field
                label="Max Attempts"
                name="max_attempts"
                value={get_opt(@cron, "max_attempts")}
                type="number"
                placeholder="20"
              />
            </div>

            <.form_field label="Tags" name="tags" value={format_tags(@cron)} placeholder="tag1, tag2" />

            <.form_field
              label="Args"
              name="args"
              value={format_args(@cron)}
              colspan="col-span-2"
              type="textarea"
              placeholder="{}"
              rows={1}
            />

            <div class="col-span-2 flex items-end gap-4 p-3 bg-violet-50 dark:bg-violet-950/30 rounded-md ring-1 ring-violet-200 dark:ring-violet-800">
              <.form_field
                label="Name"
                name="name"
                value={@cron.name}
                disabled={not @cron.dynamic?}
                hint="Changing the name will reset cron history"
                colspan="flex-1"
              />

              <div class="pb-2 pr-6">
                <.checkbox_field
                  label="Guaranteed"
                  name="guaranteed"
                  checked={get_opt(@cron, "guaranteed") == true}
                  disabled={not @cron.dynamic?}
                  hint="Ensures a job is inserted even if the scheduled time passed"
                />
              </div>
            </div>

            <div class="col-span-2 flex justify-end items-center gap-3 pt-6">
              <a
                :if={not @cron.dynamic?}
                rel="static-blocker"
                href="https://oban.pro/docs/pro/Oban.Pro.Plugins.DynamicCron.html"
                target="_blank"
                class="text-xs text-gray-500 dark:text-gray-400 hover:underline"
              >
                Editing requires DynamicCron
                <Icons.arrow_top_right_on_square class="w-3 h-3 inline-block" />
              </a>
              <.save_button disabled={not @changed?} />
            </div>
          </form>
        </fieldset>
      </div>
    </div>
    """
  end

  attr :cron, :any, required: true

  defp history_chart(assigns) do
    ~H"""
    <div class="group relative">
      <div
        id="cron-chart"
        class="h-48 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
        phx-hook="CronChart"
        phx-update="ignore"
      >
      </div>
      <.link
        navigate={oban_path(:jobs, %{meta: [["cron_name"], @cron.name], state: "completed"})}
        class="absolute right-4 top-4 flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:bg-blue-100 hover:text-blue-600 dark:hover:bg-blue-900 dark:hover:text-blue-300 opacity-0 group-hover:opacity-100 transition-opacity"
      >
        View all jobs <Icons.arrow_right class="w-3 h-3" />
      </.link>
    </div>
    """
  end

  attr :disabled, :boolean, default: false

  defp save_button(assigns) do
    ~H"""
    <button
      type="submit"
      disabled={@disabled}
      class="px-6 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
    >
      Update Entry
    </button>
    """
  end

  # Callbacks

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    chart_data = Enum.map(assigns.history, &chart_point/1)

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:changed?, fn -> false end)
      |> push_event("cron-history", %{history: chart_data})

    {:ok, socket}
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

    worker = Module.safe_concat([cron.worker])
    args = Map.get(cron.opts, "args", %{})

    opts =
      cron.opts
      |> Map.take(~w(max_attempts priority queue tags))
      |> Keyword.new(fn {key, val} -> {String.to_existing_atom(key), val} end)
      |> Keyword.put(:meta, %{cron: true, cron_expr: cron.expression, cron_name: cron.name})

    changeset = worker.new(args, opts)

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
    enforce_access!(:pause_queues, socket.assigns.access)

    %{cron: cron, conf: conf} = socket.assigns

    paused? = not cron.paused?

    DynamicCron.update(conf.name, cron.name, paused: paused?)

    {:noreply, assign(socket, cron: %{cron | paused?: paused?})}
  end

  def handle_event("delete-cron", _params, socket) do
    enforce_access!(:delete_jobs, socket.assigns.access)

    %{cron: cron, conf: conf, params: params} = socket.assigns

    case DynamicCron.delete(conf.name, cron.name) do
      {:ok, _deleted} ->
        send(self(), {:flash, :info, "Deleted cron #{cron.name}"})
        {:noreply, push_patch(socket, to: oban_path(:crons, params))}

      {:error, _reason} ->
        send(self(), {:flash, :error, "Failed to delete cron"})
        {:noreply, socket}
    end
  end

  def handle_event("form-change", params, socket) do
    changed? =
      params
      |> parse_form_params(socket.assigns.cron)
      |> Enum.any?(fn {_key, val} -> not is_nil(val) end)

    {:noreply, assign(socket, changed?: changed?)}
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    {:noreply, push_patch(socket, to: oban_path(:crons, socket.assigns.params))}
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save-cron", params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    %{cron: cron, conf: conf} = socket.assigns

    opts =
      params
      |> parse_form_params(cron)
      |> Enum.reject(fn {_key, val} -> is_nil(val) end)

    case DynamicCron.update(conf.name, cron.name, opts) do
      {:ok, _entry} ->
        send(self(), :refresh)
        send(self(), {:flash, :info, "Cron configuration updated"})
        {:noreply, assign(socket, changed?: false)}

      {:error, _reason} ->
        send(self(), {:flash, :error, "Failed to update cron configuration"})
        {:noreply, socket}
    end
  end

  # Helpers

  defp parse_form_params(params, cron) do
    [
      name: new_val?(parse_string(params["name"]), cron.name),
      worker: new_val?(parse_worker(params["worker"]), cron.worker),
      expression: new_val?(params["expression"], cron.expression),
      queue: new_val?(parse_string(params["queue"]), get_opt(cron, "queue"), "default"),
      timezone: new_val?(parse_string(params["timezone"]), get_opt(cron, "timezone"), "Etc/UTC"),
      priority: new_val?(parse_int(params["priority"]), get_opt(cron, "priority")),
      max_attempts: new_val?(parse_int(params["max_attempts"]), get_opt(cron, "max_attempts")),
      guaranteed: new_val?(params["guaranteed"] == "true", get_opt(cron, "guaranteed") == true),
      tags: new_val?(parse_tags(params["tags"]), get_opt(cron, "tags")),
      args: new_val?(parse_json(params["args"]), get_opt(cron, "args"))
    ]
  end

  defp parse_worker(nil), do: nil
  defp parse_worker(""), do: nil
  defp parse_worker(worker), do: worker

  defp new_val?(new_val, current_val, default \\ nil)
  defp new_val?(nil, _current, _default), do: nil
  defp new_val?("", _current, _default), do: nil
  defp new_val?(val, val, _default), do: nil
  defp new_val?(val, nil, val), do: nil
  defp new_val?(val, _current, _default), do: val

  defp maybe_to_unix(nil), do: ""

  defp maybe_to_unix(timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  defp get_opt(%{opts: opts}, key) do
    Map.get(opts, key)
  end

  defp format_tags(%{opts: %{"tags" => tags}}) when is_list(tags), do: Enum.join(tags, ", ")
  defp format_tags(_), do: nil

  defp format_args(%{opts: %{"args" => args}}) when is_map(args), do: Oban.JSON.encode!(args)
  defp format_args(_), do: nil

  defp state_label(nil), do: "Unknown"
  defp state_label(state), do: String.capitalize(state)

  attr :state, :string, required: true
  attr :paused, :boolean, default: false

  defp state_icon(%{paused: true} = assigns) do
    ~H"""
    <Icons.pause_circle class="w-5 h-5 text-gray-400" />
    """
  end

  defp state_icon(%{state: nil} = assigns) do
    ~H"""
    <Icons.minus_circle class="w-5 h-5 text-gray-400" />
    """
  end

  defp state_icon(%{state: "available"} = assigns) do
    ~H"""
    <Icons.pause_circle class="w-5 h-5 text-teal-400" />
    """
  end

  defp state_icon(%{state: "cancelled"} = assigns) do
    ~H"""
    <Icons.x_circle class="w-5 h-5 text-violet-400" />
    """
  end

  defp state_icon(%{state: "completed"} = assigns) do
    ~H"""
    <Icons.check_circle class="w-5 h-5 text-cyan-400" />
    """
  end

  defp state_icon(%{state: "discarded"} = assigns) do
    ~H"""
    <Icons.exclamation_circle class="w-5 h-5 text-rose-400" />
    """
  end

  defp state_icon(%{state: "executing"} = assigns) do
    ~H"""
    <Icons.play_circle class="w-5 h-5 text-orange-400" />
    """
  end

  defp state_icon(%{state: "retryable"} = assigns) do
    ~H"""
    <Icons.arrow_path class="w-5 h-5 text-yellow-400" />
    """
  end

  defp state_icon(%{state: "scheduled"} = assigns) do
    ~H"""
    <Icons.play_circle class="w-5 h-5 text-emerald-400" />
    """
  end

  defp state_icon(assigns) do
    ~H"""
    <Icons.minus_circle class="w-5 h-5 text-gray-400" />
    """
  end
end
