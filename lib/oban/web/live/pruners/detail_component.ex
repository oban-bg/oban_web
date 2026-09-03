defmodule Oban.Web.Pruners.DetailComponent do
  use Oban.Web, :live_component

  import Oban.Web.FormComponents
  import Oban.Web.Pruners.Helpers

  alias Oban.Web.Pruners.Form

  @impl Phoenix.LiveComponent
  def render(assigns) do
    shadows = shadowed_by(assigns.rule, assigns.rules)

    assigns =
      assign(assigns,
        changed?: assigns.form != assigns.baseline,
        position: position_of(assigns.rule, assigns.rules),
        shadows: shadows,
        shadowed: MapSet.new(shadows, & &1.name),
        total: length(assigns.rules)
      )

    ~H"""
    <div id="pruner-details">
      <.header
        access={@access}
        changed?={@changed?}
        configured?={@configured?}
        myself={@myself}
        rule={@rule}
        shadows={@shadows}
      />

      <div class="px-3 py-6">
        <.chain
          changed?={@changed?}
          position={@position}
          rule={@rule}
          rules={@rules}
          shadowed={@shadowed}
          total={@total}
        />

        <fieldset
          id="pruner-form-fields"
          class="mt-6"
          disabled={not can?(:update_pruners, @access)}
        >
          <form
            id="pruner-form"
            phx-change="form-change"
            phx-submit="save-rule"
            phx-target={@myself}
          >
            <div class="grid grid-cols-2 gap-x-10 gap-y-6">
              <.match_panel form={@form} rule={@rule} />
              <.retention_panel form={@form} />
            </div>

            <div
              :if={@errors != []}
              id="pruner-form-errors"
              role="alert"
              class="mt-4 px-3 py-2 rounded-md bg-red-50 dark:bg-red-900/20 text-sm text-red-700 dark:text-red-300 space-y-1"
            >
              <p :for={error <- @errors}>{error}</p>
            </div>

            <div
              :if={can?(:update_pruners, @access)}
              class="mt-6 flex justify-end items-center gap-4"
            >
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
  attr :configured?, :boolean, required: true
  attr :myself, :any, required: true
  attr :rule, :map, required: true
  attr :shadows, :list, required: true

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
            {@rule.name} <span class="font-normal text-gray-500 dark:text-gray-400">Pruner</span>
          </span>
        </button>
      </h2>

      <div class="flex items-center space-x-3">
        <Core.status_badge
          :if={@shadows != []}
          id="status-shadowed"
          color="amber"
          icon="exclamation_circle"
          label="Shadowed"
          tooltip={shadow_title(@shadows)}
        />
        <Core.status_badge
          :if={@rule.paused}
          id="status-paused"
          icon="pause_circle"
          label="Paused"
        />
        <Core.status_badge
          :if={@rule.archive}
          id="status-archive"
          icon="square_stack"
          label="Archiving"
        />
        <Core.status_badge
          :if={default?(@rule)}
          id="status-default"
          icon="square_2x2"
          label="Default"
        />
        <Core.status_badge
          :if={@configured?}
          id="status-configured"
          icon="command_line"
          label="Configured"
        />

        <Core.icon_button
          id="detail-pause-resume"
          icon={if @rule.paused, do: "play_circle", else: "pause_circle"}
          label={if @rule.paused, do: "Resume", else: "Pause"}
          color="yellow"
          tooltip={if @rule.paused, do: "Resume this rule", else: "Skip this rule while pruning"}
          disabled={not can?(:pause_pruners, @access)}
          phx-target={@myself}
          phx-click={if @rule.paused, do: "resume-rule", else: "pause-rule"}
        />

        <Core.icon_button
          id="detail-delete"
          icon="trash"
          label="Delete"
          color="red"
          tooltip={
            if default?(@rule),
              do: "The default rule can't be deleted",
              else: "Delete this rule"
          }
          disabled={default?(@rule) or not can?(:delete_pruners, @access)}
          confirm={"Delete the #{@rule.name} rule? Its jobs will fall through to later rules instead."}
          phx-target={@myself}
          phx-click="delete-rule"
        />
      </div>
    </div>
    """
  end

  attr :changed?, :boolean, required: true
  attr :position, :integer, required: true
  attr :rule, :map, required: true
  attr :rules, :list, required: true
  attr :shadowed, :any, required: true
  attr :total, :integer, required: true

  defp chain(assigns) do
    ~H"""
    <div id="pruner-chain">
      <div class="flex items-baseline">
        <h3 class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
          Rule Chain
        </h3>

        <span
          id="pruner-evaluation"
          class="ml-auto text-sm text-gray-600 dark:text-gray-300 tabular"
        >
          {@position} of {@total}
        </span>
      </div>

      <ol class="mt-2 p-2 space-y-0.5 max-h-80 overflow-y-auto bg-gray-50 dark:bg-gray-800 rounded-md">
        <li :for={{other, index} <- Enum.with_index(@rules, 1)}>
          <.link
            aria-current={other.name == @rule.name && "true"}
            data-confirm={@changed? && "Discard unsaved changes?"}
            class={[
              "flex items-center gap-3 px-2 py-1.5 rounded",
              "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500",
              other.paused && "opacity-75",
              if(other.name == @rule.name,
                do: "bg-blue-100 dark:bg-blue-900/30",
                else: "hover:bg-gray-100 dark:hover:bg-gray-700"
              )
            ]}
            id={"chain-#{dom_name(other)}"}
            patch={oban_path([:pruners, other.name])}
          >
            <span class="w-4 shrink-0 text-right text-xs tabular text-gray-400 dark:text-gray-500">
              {index}
            </span>

            <span class="w-32 shrink-0 truncate text-sm font-medium text-gray-700 dark:text-gray-300">
              {other.name}
            </span>

            <div class="flex-1 min-w-0 flex flex-wrap items-center gap-1">
              <span
                :if={match_pairs(other) == []}
                class="text-xs italic text-gray-500 dark:text-gray-400"
              >
                all jobs
              </span>

              <span
                :for={{field, value} <- match_pairs(other)}
                class="inline-flex items-center max-w-full rounded text-xs bg-gray-200/70 dark:bg-gray-700"
              >
                <span class="px-1.5 py-0.5 text-gray-500 dark:text-gray-400">{field}</span>
                <span class="px-1.5 py-0.5 font-medium text-gray-700 dark:text-gray-300 truncate">
                  {value}
                </span>
              </span>
            </div>

            <span class="w-24 shrink-0 text-right text-xs tabular text-gray-600 dark:text-gray-400">
              {format_mode(other)}
            </span>

            <span class="w-4 shrink-0">
              <Icons.icon
                :if={other.paused}
                name="icon-pause-circle"
                class="w-4 h-4 text-gray-400 dark:text-gray-500"
                rel="is-paused"
              />
              <span :if={other.paused} class="sr-only">Paused</span>
              <Icons.icon
                :if={MapSet.member?(@shadowed, other.name)}
                name="icon-exclamation-circle"
                class="w-4 h-4 text-amber-500 dark:text-amber-400"
                rel="is-shadowing"
              />
              <span :if={MapSet.member?(@shadowed, other.name)} class="sr-only">
                Shadows this rule
              </span>
            </span>
          </.link>
        </li>
      </ol>
    </div>
    """
  end

  attr :form, :map, required: true
  attr :rule, :map, required: true

  defp match_panel(assigns) do
    ~H"""
    <div id="pruner-match">
      <div class="flex items-baseline">
        <h3 class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
          Match
        </h3>

        <.link
          id="pruner-view-jobs"
          navigate={jobs_path(@rule)}
          class="ml-auto flex items-center gap-1 text-xs font-medium text-gray-500 dark:text-gray-400 hover:text-blue-500 dark:hover:text-blue-400 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
        >
          View matching jobs <Icons.icon name="icon-arrow-right" class="w-3 h-3" />
        </.link>
      </div>

      <div class="mt-3 space-y-4">
        <.form_field
          label="Queue"
          name="queue"
          value={@form.queue}
          placeholder="any queue"
          hint="Only prune jobs from this queue"
        />

        <.form_field
          label="Worker"
          name="worker"
          value={@form.worker}
          placeholder="any worker"
          hint="Only prune jobs for this worker"
        />

        <.select_field label="State" name="state" value={@form.state} options={Form.state_options()} />
      </div>
    </div>
    """
  end

  attr :form, :map, required: true

  defp retention_panel(assigns) do
    ~H"""
    <div id="pruner-retention">
      <h3 class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
        Retention
      </h3>

      <div class="mt-3 space-y-4">
        <.select_field label="Retain" name="kind" value={@form.kind} options={Form.kind_options()} />

        <div :if={@form.kind == "age"} class="grid grid-cols-2 gap-4">
          <.form_field
            label="Age"
            name="age_value"
            value={@form.age_value}
            type="number"
            min={Form.min_age(@form)}
            placeholder="7"
            required={true}
          />

          <.select_field
            label="Unit"
            name="age_unit"
            value={@form.age_unit}
            options={Form.unit_options()}
          />
        </div>

        <.form_field
          :if={@form.kind == "length"}
          label="Length"
          name="length_value"
          value={@form.length_value}
          type="number"
          min={1}
          placeholder="1000"
          required={true}
          hint="Number of most recent jobs to keep"
        />

        <p :if={@form.kind == "forever"} class="text-sm italic text-gray-500 dark:text-gray-400">
          Matching jobs are never pruned.
        </p>

        <div class="grid grid-cols-2 gap-4">
          <.form_field
            label="Limit"
            name="limit"
            value={@form.limit}
            type="number"
            min={1}
            max={Form.max_limit()}
            placeholder="10000"
            hint="Max jobs deleted per pass"
          />

          <.form_field
            label="Timeout"
            name="timeout"
            value={@form.timeout}
            type="number"
            min={1}
            placeholder="60000"
            hint="Milliseconds each pass may spend deleting"
          />
        </div>

        <.checkbox_field
          label="Archive"
          name="archive"
          checked={@form.archive}
          hint="Copy jobs into the archive table instead of discarding them"
        />
      </div>
    </div>
    """
  end

  # Callbacks

  @impl Phoenix.LiveComponent
  def update(%{failure: failure}, socket) do
    {:ok, assign(socket, errors: Form.format_failure(failure))}
  end

  # Saving advances the rule's lock version, so the form reseeds to keep editing from the values
  # that are now stored.
  def update(%{reseed: true}, socket) do
    {:ok, assign_seed(socket, socket.assigns.rule)}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:errors, fn -> [] end)

    # Refreshes replace the rule every second, and patching along the chain swaps it entirely.
    # Freshness is per field: an untouched field tracks the live rule (including the lock
    # version, which makes a save after a conflict succeed), while a field with edits in
    # progress keeps them.
    if Map.get(socket.assigns, :seeded) == assigns.rule.name do
      fresh = Form.seed(assigns.rule)
      %{baseline: baseline, form: form} = socket.assigns

      {:ok, assign(socket, baseline: fresh, form: merge_fresh(form, baseline, fresh))}
    else
      {:ok, assign_seed(socket, assigns.rule)}
    end
  end

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("pause-rule", _params, socket) do
    enforce_access!(:pause_pruners, socket.assigns.access)

    send(self(), {:pause_rule, socket.assigns.rule})

    {:noreply, socket}
  end

  def handle_event("resume-rule", _params, socket) do
    enforce_access!(:pause_pruners, socket.assigns.access)

    send(self(), {:resume_rule, socket.assigns.rule})

    {:noreply, socket}
  end

  def handle_event("delete-rule", _params, socket) do
    enforce_access!(:delete_pruners, socket.assigns.access)

    send(self(), {:delete_rule, socket.assigns.rule})

    {:noreply, socket}
  end

  def handle_event("form-change", params, socket) do
    form = Map.merge(socket.assigns.form, Form.cast_params(params))

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("discard-changes", _params, socket) do
    {:noreply, assign_seed(socket, socket.assigns.rule)}
  end

  def handle_event("save-rule", params, socket) do
    enforce_access!(:update_pruners, socket.assigns.access)

    form = Map.merge(socket.assigns.form, Form.cast_params(params))
    socket = assign(socket, form: form)

    case Form.build_opts(form) do
      {:ok, opts} ->
        send(self(), {:update_rule, form.name, form.lock_version, opts})

        {:noreply, assign(socket, errors: [])}

      {:error, message} ->
        {:noreply, assign(socket, errors: [message])}
    end
  end

  # Helpers

  defp assign_seed(socket, rule) do
    form = Form.seed(rule)

    assign(socket, baseline: form, errors: [], form: form, seeded: rule.name)
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

  # Rules without a state match prune all prunable states, but the jobs page shows one state at a
  # time, so completed stands in as the state with the most jobs to show.
  defp jobs_path(rule) do
    match = Map.new(match_pairs(rule))

    params =
      %{
        state: Map.get(match, :state, "completed"),
        queues: Map.get(match, :queue),
        workers: Map.get(match, :worker)
      }
      |> Map.reject(fn {_key, value} -> is_nil(value) end)

    oban_path(:jobs, params)
  end

  defp shadow_names(shadows), do: Enum.map_join(shadows, ", ", & &1.name)

  defp shadow_title([shadow]), do: "#{shadow.name} claims every job this rule matches"
  defp shadow_title(shadows), do: "#{shadow_names(shadows)} claim every job this rule matches"
end
