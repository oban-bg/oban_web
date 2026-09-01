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
      <.header access={@access} changed?={@changed?} myself={@myself} rule={@rule} />

      <div class="grid grid-cols-3 gap-6 px-3 py-6">
        <div class="col-span-2">
          <.chain
            changed?={@changed?}
            position={@position}
            rule={@rule}
            rules={@rules}
            shadowed={@shadowed}
            total={@total}
          />

          <p
            :if={@rule.paused}
            id="pruner-paused-note"
            class="mt-3 text-sm text-gray-600 dark:text-gray-400"
          >
            While paused this rule drops out of the chain entirely, so its jobs fall through to
            whichever later rule matches them next, rather than being retained.
          </p>

          <p
            :if={@shadows != []}
            id="pruner-shadowed-note"
            class="mt-3 text-sm text-amber-700 dark:text-amber-400"
          >
            Nothing reaches this rule. Every job it matches is already claimed by {shadow_names(
              @shadows
            )}, which {shadow_verb(@shadows)} earlier in the chain.
          </p>
        </div>

        <div class="col-span-1 space-y-6">
          <.match_section rule={@rule} />
          <.retention_section rule={@rule} />
          <.metadata rule={@rule} />
        </div>
      </div>

      <.editor
        access={@access}
        changed?={@changed?}
        configured?={@configured?}
        errors={@errors}
        form={@form}
        myself={@myself}
      />
    </div>
    """
  end

  attr :access, :any, required: true
  attr :changed?, :boolean, required: true
  attr :myself, :any, required: true
  attr :rule, :map, required: true

  defp header(assigns) do
    ~H"""
    <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
      <button
        id="back-link"
        class="flex items-center min-w-0 hover:text-blue-500 cursor-pointer bg-transparent border-0 p-0 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
        data-confirm-back={@changed? && "Discard unsaved changes?"}
        data-escape-back={true}
        phx-hook="HistoryBack"
        type="button"
      >
        <Icons.icon name="icon-arrow-left" class="w-5 h-5 shrink-0" />
        <span class="text-lg font-bold ml-2 truncate">{@rule.name}</span>
      </button>

      <div class="flex items-center space-x-3">
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
        <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
          Evaluation Chain
        </span>

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
                do: "bg-white dark:bg-gray-900 ring-1 ring-blue-500 dark:ring-blue-400",
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
                class="w-4 h-4 text-amber-500"
                rel="is-shadowing"
              />
              <span :if={MapSet.member?(@shadowed, other.name)} class="sr-only">
                Shadows this rule
              </span>
            </span>
          </.link>
        </li>
      </ol>

      <p class="mt-2 text-xs text-gray-500 dark:text-gray-400">
        Rules match in order, so each one prunes only the jobs that the rules above it didn't
        already claim.
      </p>
    </div>
    """
  end

  attr :rule, :map, required: true

  defp match_section(assigns) do
    ~H"""
    <div id="pruner-match">
      <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
        Match
      </span>

      <dl class="mt-2 space-y-2">
        <p :if={match_pairs(@rule) == []} class="text-sm text-gray-600 dark:text-gray-400">
          Every completed, cancelled, and discarded job.
        </p>

        <div :for={{field, value} <- match_pairs(@rule)} class="flex items-baseline text-sm">
          <dt class="w-20 shrink-0 text-gray-500 dark:text-gray-400">{field}</dt>
          <dd class="font-medium text-gray-700 dark:text-gray-300 break-all">{value}</dd>
        </div>
      </dl>
    </div>
    """
  end

  attr :rule, :map, required: true

  defp retention_section(assigns) do
    ~H"""
    <div id="pruner-retention">
      <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
        Retention
      </span>

      <dl class="mt-2 space-y-2">
        <div class="flex items-baseline text-sm">
          <dt class="w-20 shrink-0 text-gray-500 dark:text-gray-400">{mode_label(@rule)}</dt>
          <dd class="font-medium tabular text-gray-700 dark:text-gray-300">{format_mode(@rule)}</dd>
        </div>

        <div class="flex items-baseline text-sm">
          <dt class="w-20 shrink-0 text-gray-500 dark:text-gray-400">limit</dt>
          <dd class="tabular text-gray-700 dark:text-gray-300">
            {format_limit(@rule)} <span class="text-gray-500 dark:text-gray-400">per pass</span>
          </dd>
        </div>

        <div class="flex items-baseline text-sm">
          <dt class="w-20 shrink-0 text-gray-500 dark:text-gray-400">timeout</dt>
          <dd class="tabular text-gray-700 dark:text-gray-300">{format_timeout(@rule)}</dd>
        </div>
      </dl>
    </div>
    """
  end

  attr :rule, :map, required: true

  defp metadata(assigns) do
    ~H"""
    <div
      id="pruner-metadata"
      class="flex items-center space-x-6 pt-3 border-t border-gray-100 dark:border-gray-800 text-xs text-gray-500 dark:text-gray-400"
    >
      <span>
        Created
        <time
          id="pruner-inserted-at"
          datetime={to_iso8601(@rule.inserted_at)}
          data-timestamp={to_unix(@rule.inserted_at)}
          phx-hook="Relativize"
          phx-update="ignore"
        >
          -
        </time>
      </span>

      <span>
        Updated
        <time
          id="pruner-updated-at"
          datetime={to_iso8601(@rule.updated_at)}
          data-timestamp={to_unix(@rule.updated_at)}
          phx-hook="Relativize"
          phx-update="ignore"
        >
          -
        </time>
      </span>
    </div>
    """
  end

  attr :access, :any, required: true
  attr :changed?, :boolean, required: true
  attr :configured?, :boolean, required: true
  attr :errors, :list, required: true
  attr :form, :map, required: true
  attr :myself, :any, required: true

  defp editor(assigns) do
    ~H"""
    <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
      <h3 class="flex items-center font-semibold mb-3 space-x-2 text-gray-500 dark:text-gray-400">
        <Icons.icon name="icon-pencil-square" />
        <span>Edit Configuration</span>
      </h3>

      <div
        :if={@configured?}
        id="pruner-form-configured"
        class="mb-3 px-3 py-2 rounded-md bg-amber-50 dark:bg-amber-900/20 text-sm text-amber-800 dark:text-amber-300"
      >
        This rule is declared in your Oban configuration. Changes made here, apart from pausing and
        reordering, are replaced from that configuration whenever the pruner restarts.
      </div>

      <div
        :if={@errors != []}
        id="pruner-form-errors"
        class="mb-3 px-3 py-2 rounded-md bg-red-50 dark:bg-red-900/20 text-sm text-red-700 dark:text-red-300 space-y-1"
      >
        <p :for={error <- @errors}>{error}</p>
      </div>

      <fieldset id="pruner-form-fields" disabled={not can?(:update_pruners, @access)}>
        <form
          id="pruner-form"
          class="grid grid-cols-4 gap-4 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
          phx-change="form-change"
          phx-submit="save-rule"
          phx-target={@myself}
        >
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

          <.select_field
            label="State"
            name="state"
            value={@form.state}
            options={Form.state_options()}
          />

          <.select_field
            label="Retain"
            name="kind"
            value={@form.kind}
            options={Form.kind_options()}
          />

          <div :if={@form.kind == "age"} class="grid grid-cols-2 gap-4">
            <.form_field
              label="Age"
              name="age_value"
              value={@form.age_value}
              type="number"
              min={1}
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

          <p
            :if={@form.kind == "forever"}
            class="flex items-end pb-2 text-sm text-gray-500 dark:text-gray-400"
          >
            Matching jobs are never pruned.
          </p>

          <.form_field
            label="Limit"
            name="limit"
            value={@form.limit}
            type="number"
            min={1}
            max={Form.max_limit()}
            placeholder="10000"
            hint="Maximum jobs deleted per pass"
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

          <.checkbox_field
            label="Archive"
            name="archive"
            checked={@form.archive}
            colspan="flex items-end pb-2"
            hint="Copy jobs into the archive table instead of discarding them"
          />

          <div class="col-span-4 flex justify-end items-center pt-2">
            <button
              type="submit"
              disabled={not @changed?}
              class="px-6 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Save Changes
            </button>
          </div>
        </form>
      </fieldset>
    </div>
    """
  end

  # Callbacks

  @impl Phoenix.LiveComponent
  def update(%{failure: failure}, socket) do
    socket = assign(socket, errors: Form.format_failure(failure))

    # A stale save arrives after the page reloads the rule, so adopting the current lock version
    # lets the next save succeed instead of repeating the same conflict.
    if Form.stale?(failure) do
      %{baseline: baseline, form: form, rule: rule} = socket.assigns

      {:ok,
       assign(socket,
         baseline: %{baseline | lock_version: rule.lock_version},
         form: %{form | lock_version: rule.lock_version}
       )}
    else
      {:ok, socket}
    end
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
    # An untouched form follows those replacements so it never displays outdated values, while a
    # form with edits in progress is left alone.
    cond do
      Map.get(socket.assigns, :seeded) != assigns.rule.name ->
        {:ok, assign_seed(socket, assigns.rule)}

      socket.assigns.form == socket.assigns.baseline ->
        {:ok, assign_seed(socket, assigns.rule)}

      true ->
        {:ok, socket}
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

  defp shadow_names(shadows), do: Enum.map_join(shadows, ", ", & &1.name)

  defp shadow_verb([_shadow]), do: "runs"
  defp shadow_verb(_shadows), do: "run"
end
