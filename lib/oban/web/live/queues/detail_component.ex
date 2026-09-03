defmodule Oban.Web.Queues.DetailComponent do
  use Oban.Web, :live_component

  import Oban.Web.FormComponents
  import Oban.Web.Helpers.QueueHelper

  alias Oban.Config
  alias Oban.Met
  alias Oban.Web.Colors
  alias Oban.Web.Components.Core
  alias Oban.Web.Metrics
  alias Oban.Web.Queue
  alias Oban.Web.Queues.DetailInstanceComponent
  alias Oban.Web.Timing
  alias Oban.Web.Utils

  @history_by 5
  @history_lookback 300

  @impl Phoenix.LiveComponent
  def update(%{local_limit: new_limit}, socket) do
    %{checks: checks, inputs: inputs} = socket.assigns

    local_limit =
      cond do
        match?([_], checks) ->
          new_limit

        match?([_ | _], checks) ->
          max(local_limit(checks), new_limit)

        true ->
          inputs.local_limit
      end

    inputs = %{inputs | local_limit: local_limit}

    {:ok, assign(socket, inputs: inputs)}
  end

  def update(assigns, socket) do
    checks = Enum.filter(assigns.checks, &(&1["queue"] == assigns.queue))
    queue = %Queue{name: assigns.queue, checks: checks}

    previous_counts = Map.get(socket.assigns, :counts, %{})
    counts = Metrics.queue_state_counts(assigns.conf.name, assigns.queue, previous_counts)

    history = queue_history(assigns.conf, assigns.queue)

    socket =
      socket
      |> assign(access: assigns.access, conf: assigns.conf, queue: assigns.queue)
      |> assign(counts: counts, checks: checks, queue_struct: queue, history: history)
      |> assign(node_history: assigns[:node_history] || %{})
      |> assign_new(:instances_open?, fn -> true end)
      |> assign_new(:config_open?, fn -> false end)
      |> assign_new(:errors, fn -> %{} end)
      |> assign_new(:invalid, fn -> [] end)
      |> assign_new(:inputs, fn ->
        %{
          local_limit: local_limit(checks),
          global_allowed: global_allowed(checks),
          global_burst: global_burst(checks),
          global_per_node: global_per_node(checks),
          global_partition_fields: partition_value(checks, "global_limit", "fields"),
          global_partition_keys: partition_value(checks, "global_limit", "keys"),
          rate_allowed: rate_allowed(checks),
          rate_period: rate_period(checks),
          rate_partition_fields: partition_value(checks, "rate_limit", "fields"),
          rate_partition_keys: partition_value(checks, "rate_limit", "keys")
        }
      end)
      |> push_event("queue-history", %{history: history})

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queue-details">
      <.header
        access={@access}
        checks={@checks}
        myself={@myself}
        queue={@queue}
        queue_struct={@queue_struct}
      />

      <div class="grid grid-cols-3 gap-6 px-3 py-6">
        <div class="col-span-2">
          <.history_chart queue={@queue} />
        </div>

        <div class="col-span-1">
          <.stats_grid checks={@checks} counts={@counts} inputs={@inputs} queue={@queue} />
        </div>
      </div>

      <.instances_section
        access={@access}
        checks={@checks}
        error={@errors[:local]}
        inputs={@inputs}
        instances_open?={@instances_open?}
        myself={@myself}
        node_history={@node_history}
        queue={@queue}
      />

      <.config_section
        access={@access}
        checks={@checks}
        conf={@conf}
        config_open?={@config_open?}
        errors={@errors}
        inputs={@inputs}
        invalid={@invalid}
        myself={@myself}
        queue={@queue}
      />
    </div>
    """
  end

  # Header Component

  defp header(assigns) do
    all_paused? = Queue.all_paused?(assigns.queue_struct)
    any_paused? = Queue.any_paused?(assigns.queue_struct)
    terminating? = Queue.terminating?(assigns.queue_struct)

    assigns =
      assign(assigns,
        all_paused?: all_paused?,
        any_paused?: any_paused?,
        terminating?: terminating?
      )

    ~H"""
    <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
      <h2 class="min-w-0">
        <button
          id="back-link"
          class="flex items-center min-w-0 max-w-full hover:text-blue-500 cursor-pointer bg-transparent border-0 p-0 rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
          data-escape-back={true}
          phx-hook="HistoryBack"
          type="button"
        >
          <Icons.icon name="icon-arrow-left" class="w-5 h-5 shrink-0" />
          <span class="text-lg font-bold ml-2 truncate">
            {@queue} <span class="font-normal text-gray-500 dark:text-gray-400">Queue</span>
          </span>
        </button>
      </h2>

      <div class="flex shrink-0 space-x-3">
        <Core.status_badge
          :if={@terminating?}
          id="status-terminating"
          icon="power"
          label="Terminating"
        />
        <Core.status_badge
          :if={@all_paused? and not @terminating?}
          id="status-paused"
          icon="pause_circle"
          label="Paused"
        />
        <Core.status_badge
          :if={@any_paused? and not @all_paused? and not @terminating?}
          id="status-partial"
          icon="play_pause_circle"
          label="Partial"
        />

        <Core.icon_button
          id="detail-pause-resume"
          icon={if @all_paused?, do: "play_circle", else: "pause_circle"}
          label={if @all_paused?, do: "Resume", else: "Pause"}
          color="yellow"
          tooltip={if @all_paused?, do: "Resume all nodes", else: "Pause all nodes"}
          disabled={not can?(:pause_queues, @access)}
          phx-target={@myself}
          phx-click={if @all_paused?, do: "resume-queue", else: "pause-queue"}
        />

        <Core.icon_button
          id="detail-stop"
          icon="x_circle"
          label="Stop"
          color="red"
          tooltip="Stop this queue on all nodes"
          disabled={not can?(:stop_queues, @access)}
          confirm={stop_confirm(@queue, @checks)}
          phx-target={@myself}
          phx-click="stop-queue"
        />
      </div>
    </div>
    """
  end

  # History Chart Component

  defp history_chart(assigns) do
    ~H"""
    <div class="group relative h-full">
      <div
        id="queue-detail-chart"
        class="h-full min-h-64 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
        role="img"
        aria-label={"Jobs executed in the #{@queue} queue over the last 5 minutes"}
        phx-hook="QueueDetailChart"
        phx-update="ignore"
      >
      </div>
      <.link
        navigate={oban_path(:jobs, %{queues: @queue, state: "completed"})}
        class="absolute right-4 top-4 flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:bg-blue-100 hover:text-blue-600 dark:hover:bg-blue-900 dark:hover:text-blue-300 opacity-0 group-hover:opacity-100 focus-visible:opacity-100 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 transition-opacity"
      >
        View all jobs <Icons.icon name="icon-arrow-right" class="w-3 h-3" />
      </.link>
    </div>
    """
  end

  # Stats Grid Component

  @state_order ~w(executing available scheduled retryable cancelled discarded completed)

  defp stats_grid(assigns) do
    states =
      for state <- @state_order do
        count =
          case state do
            "executing" -> executing_count(assigns.checks)
            _ -> assigns.counts[state] || 0
          end

        {state, count}
      end

    assigns = assign(assigns, states: states)

    ~H"""
    <div class="flex flex-col gap-4">
      <ul id="queue-state-counts" class="bg-gray-50 dark:bg-gray-800 rounded-md p-3 space-y-0.5">
        <li :for={{state, count} <- @states}>
          <.link
            id={"queue-state-#{state}"}
            navigate={oban_path(:jobs, %{queues: @queue, state: state})}
            class={[
              "flex items-center gap-2.5 -mx-1 px-2 py-1 rounded-md",
              "hover:bg-gray-100 dark:hover:bg-gray-700",
              "focus:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
            ]}
          >
            <span class={[
              "w-2 h-2 rounded-full shrink-0",
              if(count > 0, do: Colors.state_bg_class(state), else: "bg-gray-300 dark:bg-gray-600")
            ]} />
            <span class={[
              "flex-1 text-sm",
              if(state == "executing",
                do: "font-semibold text-gray-800 dark:text-gray-200",
                else: "font-medium text-gray-600 dark:text-gray-300"
              )
            ]}>
              {state}
            </span>
            <span class={[
              "text-sm tabular",
              cond do
                state == "executing" -> "font-semibold text-gray-800 dark:text-gray-200"
                count > 0 -> "text-gray-800 dark:text-gray-200"
                true -> "text-gray-400 dark:text-gray-500"
              end
            ]}>
              {integer_to_estimate(count)}
            </span>
          </.link>
        </li>
      </ul>

      <dl id="queue-limits" class="grid grid-cols-4 gap-4 px-3">
        <div class="flex flex-col">
          <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Local Limit
          </dt>
          <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
            {local_limit_display(@checks)}
          </dd>
        </div>

        <div class="flex flex-col">
          <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Global Limit
          </dt>
          <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
            {global_limit_display(@inputs)}
          </dd>
        </div>

        <div class="flex flex-col">
          <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Rate Limit
          </dt>
          <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
            {rate_limit_display(@inputs)}
          </dd>
        </div>

        <div class="flex flex-col">
          <dt class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Last Started
          </dt>
          <dd class="text-base text-gray-800 dark:text-gray-200 tabular">
            {started_at(@checks)}
          </dd>
        </div>
      </dl>
    </div>
    """
  end

  # Instances Section Component

  defp instances_section(assigns) do
    ~H"""
    <div id="queue-instances" class="border-t border-gray-200 dark:border-gray-700">
      <div class="px-3 py-6">
        <div class="flex items-center justify-between gap-4">
          <button
            id="instances-toggle"
            type="button"
            class="flex items-center space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
            aria-controls="instances-content"
            aria-expanded={to_string(@instances_open?)}
            phx-click={toggle_instances(@myself)}
          >
            <Icons.icon
              name="icon-chevron-right"
              id="instances-chevron"
              class={["w-5 h-5 transition-transform", if(@instances_open?, do: "rotate-90")]}
            />
            <span class="font-semibold">
              Instances
              <span class="text-gray-400 dark:text-gray-500 font-normal">
                ({length(@checks)})
              </span>
            </span>
          </button>

          <form
            id="local-form"
            class="flex items-center gap-3"
            phx-target={@myself}
            phx-change="form-change"
            phx-submit="local-submit"
          >
            <label
              for="local_limit"
              class="flex items-center gap-1.5 text-sm font-medium text-gray-600 dark:text-gray-300"
            >
              <Icons.icon
                :if={not can?(:scale_queues, @access)}
                name="icon-lock-closed"
                class="w-4 h-4 text-gray-500 dark:text-gray-400"
              /> Limit on all nodes
            </label>

            <input
              type="number"
              id="local_limit"
              name="local_limit"
              value={@inputs.local_limit}
              min="1"
              required
              disabled={not can?(:scale_queues, @access)}
              aria-invalid={@error && "true"}
              aria-describedby={@error && "local-form-error"}
              class={[
                "block w-20 font-mono text-sm shadow-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50",
                if(@error,
                  do: "border-red-500 dark:border-red-400",
                  else: "border-gray-300 dark:border-gray-600"
                )
              ]}
            />

            <button
              type="submit"
              class={primary_button()}
              disabled={
                @inputs.local_limit == local_limit(@checks) or not can?(:scale_queues, @access)
              }
            >
              Scale
            </button>
          </form>
        </div>

        <.form_error id="local-form-error" error={@error} class="mt-2 text-right" />

        <div id="instances-content" class={["mt-3", unless(@instances_open?, do: "hidden")]}>
          <table class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700 border border-gray-200 dark:border-gray-700 rounded-md overflow-hidden">
            <caption class="sr-only">Nodes running the {@queue} queue</caption>
            <thead>
              <tr class="bg-gray-50 dark:bg-gray-950 text-gray-500 dark:text-gray-500">
                <th
                  scope="col"
                  class="w-1/3 text-left text-xs font-medium uppercase tracking-wider pl-3 py-3"
                >
                  Node/Name
                </th>
                <th scope="col" class="text-left text-xs font-medium uppercase tracking-wider py-3">
                  Activity
                </th>
                <th
                  scope="col"
                  class="w-20 text-right text-xs font-medium uppercase tracking-wider py-3"
                >
                  Executing
                </th>
                <th
                  scope="col"
                  class="w-20 text-right text-xs font-medium uppercase tracking-wider py-3"
                >
                  Limit
                </th>
                <th
                  scope="col"
                  class="w-20 text-right text-xs font-medium uppercase tracking-wider py-3"
                >
                  Started
                </th>
                <th
                  scope="col"
                  class="w-24 text-right text-xs font-medium uppercase tracking-wider pr-3 py-3"
                >
                  Actions
                </th>
              </tr>
            </thead>

            <tbody class="divide-y divide-gray-100 dark:divide-gray-800 bg-white dark:bg-gray-900">
              <%= for check <- @checks do %>
                <.live_component
                  access={@access}
                  checks={check}
                  id={node_name(check)}
                  module={DetailInstanceComponent}
                  node_history={Map.get(@node_history, check["node"], [])}
                />
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  # Config Section Component

  defp config_section(assigns) do
    ~H"""
    <div id="queue-config" class="border-t border-gray-200 dark:border-gray-700">
      <div class="px-3 py-6">
        <button
          id="config-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
          aria-controls="config-content"
          aria-expanded={to_string(@config_open?)}
          phx-click={toggle_config(@myself)}
        >
          <Icons.icon
            name="icon-chevron-right"
            id="config-chevron"
            class={["w-5 h-5 transition-transform", if(@config_open?, do: "rotate-90")]}
          />
          <span class="font-semibold">Global & Rate Limits</span>
        </button>

        <div id="config-content" class={["mt-3", unless(@config_open?, do: "hidden")]}>
          <div class="grid grid-cols-2 gap-x-10 gap-y-6 bg-gray-50 dark:bg-gray-800 rounded-md p-4">
            <div :if={missing_pro?(@conf)} id="global-form">
              <.panel_heading
                icon="icon-globe"
                id="global-limit-info"
                hint="Limits total concurrent jobs across all nodes"
                title="Global Limit"
              />
              <.requires_pro />
            </div>

            <form
              :if={not missing_pro?(@conf)}
              id="global-form"
              phx-change="form-change"
              phx-submit="global-update"
              phx-target={@myself}
            >
              <.panel_heading
                icon="icon-globe"
                id="global-limit-info"
                hint="Limits total concurrent jobs across all nodes"
                title="Global Limit"
              >
                <.toggle_button
                  disabled={not can?(:scale_queues, @access)}
                  enabled={not is_nil(@inputs.global_allowed)}
                  feature="global"
                  label="Global limit"
                  myself={@myself}
                />
              </.panel_heading>

              <div class="flex w-full mb-6">
                <div class="w-1/2 pr-1.5">
                  <.form_field
                    label="Allowed"
                    name="global_allowed"
                    value={@inputs.global_allowed}
                    type="number"
                    min={1}
                    required={not is_nil(@inputs.global_allowed)}
                    invalid={"global_allowed" in @invalid}
                    disabled={not can?(:scale_queues, @access) or is_nil(@inputs.global_allowed)}
                  />
                </div>
              </div>

              <div class="flex w-full space-x-3 mb-4">
                <div class="w-1/2">
                  <.select_field
                    label="Partition Fields"
                    name="global_partition_fields"
                    value={@inputs.global_partition_fields}
                    options={partition_options()}
                    disabled={not can?(:scale_queues, @access) or is_nil(@inputs.global_allowed)}
                  />
                </div>

                <div class="w-1/2">
                  <.form_field
                    label="Partition Keys"
                    name="global_partition_keys"
                    value={@inputs.global_partition_keys}
                    disabled={
                      keyless_partition?(@inputs.global_partition_fields) or
                        not can?(:scale_queues, @access)
                    }
                  />
                </div>
              </div>

              <div class="flex w-full space-x-3 mb-4">
                <.toggle_field
                  disabled={
                    not can?(:scale_queues, @access) or is_nil(@inputs.global_allowed) or
                      is_nil(@inputs.global_partition_fields)
                  }
                  enabled={@inputs.global_burst}
                  feature="burst"
                  hint="Allow partitions to exceed limit when capacity available"
                  label="Burst"
                  myself={@myself}
                />

                <.toggle_field
                  disabled={not can?(:scale_queues, @access) or is_nil(@inputs.global_allowed)}
                  enabled={@inputs.global_per_node}
                  feature="per-node"
                  hint="Scale the allowed limit by the number of nodes running the queue, best combined with a partition"
                  label="Per Node"
                  myself={@myself}
                />
              </div>

              <.form_error id="global-form-error" error={@errors[:global]} class="mt-4" />

              <.submit_input
                locked={not can?(:scale_queues, @access)}
                disabled={global_unchanged?(@checks, @inputs) or not can?(:scale_queues, @access)}
                confirm={
                  (is_nil(@inputs.global_allowed) and not is_nil(global_allowed(@checks))) &&
                    "Remove the global limit from the #{@queue} queue? Each node will run up to its local limit instead."
                }
                label="Apply"
              />
            </form>

            <div :if={missing_pro?(@conf)} id="rate-limit-form">
              <.panel_heading
                icon="icon-arrow-trending-down"
                id="rate-limit-info"
                hint="Limits how many jobs start within each period"
                title="Rate Limit"
              />
              <.requires_pro />
            </div>

            <form
              :if={not missing_pro?(@conf)}
              id="rate-limit-form"
              phx-change="form-change"
              phx-submit="rate-limit-update"
              phx-target={@myself}
            >
              <.panel_heading
                icon="icon-arrow-trending-down"
                id="rate-limit-info"
                hint="Limits how many jobs start within each period"
                title="Rate Limit"
              >
                <.toggle_button
                  disabled={not can?(:scale_queues, @access)}
                  enabled={not is_nil(@inputs.rate_allowed)}
                  feature="rate-limit"
                  label="Rate limit"
                  myself={@myself}
                />
              </.panel_heading>

              <div class="flex w-full space-x-3 mb-6">
                <div class="w-1/2">
                  <.form_field
                    label="Allowed"
                    name="rate_allowed"
                    value={@inputs.rate_allowed}
                    type="number"
                    min={1}
                    required={not is_nil(@inputs.rate_allowed)}
                    invalid={"rate_allowed" in @invalid}
                    disabled={not can?(:scale_queues, @access) or is_nil(@inputs.rate_allowed)}
                  />
                </div>

                <div class="w-1/2">
                  <.form_field
                    label="Period (seconds)"
                    name="rate_period"
                    value={@inputs.rate_period}
                    type="number"
                    min={1}
                    required={not is_nil(@inputs.rate_allowed)}
                    invalid={"rate_period" in @invalid}
                    disabled={not can?(:scale_queues, @access) or is_nil(@inputs.rate_allowed)}
                  />
                </div>
              </div>

              <div class="flex w-full space-x-3">
                <div class="w-1/2">
                  <.select_field
                    label="Partition Fields"
                    name="rate_partition_fields"
                    value={@inputs.rate_partition_fields}
                    options={partition_options()}
                    disabled={not can?(:scale_queues, @access) or is_nil(@inputs.rate_allowed)}
                  />
                </div>

                <div class="w-1/2">
                  <.form_field
                    label="Partition Keys"
                    name="rate_partition_keys"
                    value={@inputs.rate_partition_keys}
                    disabled={
                      keyless_partition?(@inputs.rate_partition_fields) or
                        not can?(:scale_queues, @access)
                    }
                  />
                </div>
              </div>

              <.form_error id="rate-limit-form-error" error={@errors[:rate]} class="mt-4" />

              <.submit_input
                locked={not can?(:scale_queues, @access)}
                disabled={rate_unchanged?(@checks, @inputs) or not can?(:scale_queues, @access)}
                confirm={
                  (is_nil(@inputs.rate_allowed) and not is_nil(rate_allowed(@checks))) &&
                    "Remove the rate limit from the #{@queue} queue? Jobs will start as fast as the other limits allow."
                }
                label="Apply"
              />
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Handlers

  @integer_inputs ~w(local_limit global_allowed rate_allowed rate_period)

  @impl Phoenix.LiveComponent
  def handle_event("form-change", %{"_target" => ["rate_partition_fields"]} = params, socket) do
    fields = params["rate_partition_fields"]
    inputs = %{socket.assigns.inputs | rate_partition_fields: fields}

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("form-change", %{"_target" => ["global_partition_fields"]} = params, socket) do
    fields = params["global_partition_fields"]
    inputs = %{socket.assigns.inputs | global_partition_fields: fields}

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("form-change", params, socket) do
    inputs =
      for {key, val} <- params, key in @integer_inputs, reduce: socket.assigns.inputs do
        acc ->
          case parse_limit(val) do
            {:ok, int} -> %{acc | String.to_existing_atom(key) => int}
            :error -> acc
          end
      end

    socket =
      socket
      |> assign(inputs: inputs)
      |> clear_error(params["_target"])

    {:noreply, socket}
  end

  def handle_event("local-submit", params, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    case parse_limit(params["local_limit"]) do
      {:ok, limit} ->
        send(self(), {:scale_queue, socket.assigns.queue, limit: limit})

        inputs = %{socket.assigns.inputs | local_limit: limit}

        {:noreply,
         assign(socket, inputs: inputs, errors: Map.delete(socket.assigns.errors, :local))}

      :error ->
        {:noreply,
         put_error(socket, :local, ["local_limit"], "Limit must be a whole number of 1 or more")}
    end
  end

  def handle_event("global-update", %{"global_allowed" => nil}, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    send(self(), {:scale_queue, socket.assigns.queue, global_limit: nil})

    inputs =
      socket.assigns.inputs
      |> Map.replace!(:global_allowed, nil)
      |> Map.replace!(:global_burst, false)
      |> Map.replace!(:global_per_node, false)
      |> Map.replace!(:global_partition_fields, "")
      |> Map.replace!(:global_partition_keys, "")

    {:noreply, assign(socket, inputs: inputs, errors: Map.delete(socket.assigns.errors, :global))}
  end

  def handle_event("global-update", params, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    case parse_limit(params["global_allowed"]) do
      {:ok, allowed} ->
        fields = maybe_split(params["global_partition_fields"])
        keys = maybe_split(params["global_partition_keys"])
        burst = fields != [] and socket.assigns.inputs.global_burst
        per_node = socket.assigns.inputs.global_per_node

        global_limit =
          case fields do
            [] ->
              %{allowed: allowed}

            ["worker"] ->
              %{allowed: allowed, partition: [fields: fields]}

            _ ->
              %{allowed: allowed, partition: [fields: fields, keys: keys]}
          end
          |> maybe_add_burst(burst)
          |> maybe_add_per_node(per_node)

        send(self(), {:scale_queue, socket.assigns.queue, global_limit: global_limit})

        inputs =
          socket.assigns.inputs
          |> Map.replace!(:global_allowed, allowed)
          |> Map.replace!(:global_burst, burst)
          |> Map.replace!(:global_per_node, per_node)
          |> Map.replace!(:global_partition_fields, Enum.join(fields, ","))
          |> Map.replace!(:global_partition_keys, Enum.join(keys, ","))

        {:noreply,
         assign(socket, inputs: inputs, errors: Map.delete(socket.assigns.errors, :global))}

      :error ->
        {:noreply,
         put_error(
           socket,
           :global,
           ["global_allowed"],
           "Allowed must be a whole number of 1 or more"
         )}
    end
  end

  def handle_event("rate-limit-update", %{"rate_allowed" => nil}, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    send(self(), {:scale_queue, socket.assigns.queue, rate_limit: nil})

    inputs =
      socket.assigns.inputs
      |> Map.replace!(:rate_allowed, nil)
      |> Map.replace!(:rate_period, nil)
      |> Map.replace!(:rate_partition_fields, "")
      |> Map.replace!(:rate_partition_keys, "")

    {:noreply, assign(socket, inputs: inputs, errors: Map.delete(socket.assigns.errors, :rate))}
  end

  def handle_event("rate-limit-update", params, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    with {:ok, allowed} <- parse_limit(params["rate_allowed"]),
         {:ok, period} <- parse_limit(params["rate_period"]) do
      fields = maybe_split(params["rate_partition_fields"])
      keys = maybe_split(params["rate_partition_keys"])

      rate_limit =
        case fields do
          [] ->
            %{allowed: allowed, period: period}

          ["worker"] ->
            %{allowed: allowed, period: period, partition: [fields: fields]}

          _ ->
            %{allowed: allowed, period: period, partition: [fields: fields, keys: keys]}
        end

      send(self(), {:scale_queue, socket.assigns.queue, rate_limit: rate_limit})

      inputs =
        socket.assigns.inputs
        |> Map.replace!(:rate_allowed, allowed)
        |> Map.replace!(:rate_period, period)
        |> Map.replace!(:rate_partition_fields, Enum.join(fields, ","))
        |> Map.replace!(:rate_partition_keys, Enum.join(keys, ","))

      {:noreply, assign(socket, inputs: inputs, errors: Map.delete(socket.assigns.errors, :rate))}
    else
      :error ->
        invalid =
          for field <- ["rate_allowed", "rate_period"],
              parse_limit(params[field]) == :error,
              do: field

        {:noreply,
         put_error(
           socket,
           :rate,
           invalid,
           "Allowed and period must be whole numbers of 1 or more"
         )}
    end
  end

  def handle_event("toggle-feature", %{"feature" => "global"}, socket) do
    inputs =
      if is_nil(socket.assigns.inputs.global_allowed) do
        socket.assigns.inputs
        |> Map.put(:global_allowed, socket.assigns.inputs.local_limit)
      else
        socket.assigns.inputs
        |> Map.put(:global_allowed, nil)
        |> Map.put(:global_burst, false)
        |> Map.put(:global_per_node, false)
        |> Map.put(:global_partition_fields, "")
        |> Map.put(:global_partition_keys, "")
      end

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("toggle-feature", %{"feature" => "burst"}, socket) do
    inputs = Map.update!(socket.assigns.inputs, :global_burst, &(not &1))

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("toggle-feature", %{"feature" => "per-node"}, socket) do
    inputs = Map.update!(socket.assigns.inputs, :global_per_node, &(not &1))

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("toggle-feature", %{"feature" => "rate-limit"}, socket) do
    inputs =
      if is_nil(socket.assigns.inputs.rate_allowed) do
        socket.assigns.inputs
        |> Map.put(:rate_allowed, socket.assigns.inputs.local_limit)
        |> Map.put(:rate_period, 60)
      else
        socket.assigns.inputs
        |> Map.put(:rate_allowed, nil)
        |> Map.put(:rate_period, nil)
        |> Map.put(:rate_partition_fields, "")
        |> Map.put(:rate_partition_keys, "")
      end

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("pause-queue", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    send(self(), {:pause_queue, socket.assigns.queue})

    {:noreply, put_paused(socket, true)}
  end

  def handle_event("resume-queue", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    send(self(), {:resume_queue, socket.assigns.queue})

    {:noreply, put_paused(socket, false)}
  end

  def handle_event("stop-queue", _params, socket) do
    enforce_access!(:stop_queues, socket.assigns.access)

    send(self(), {:stop_queue, socket.assigns.queue})

    {:noreply, socket}
  end

  def handle_event("toggle-instances", _params, socket) do
    {:noreply, assign(socket, instances_open?: not socket.assigns.instances_open?)}
  end

  def handle_event("toggle-config", _params, socket) do
    {:noreply, assign(socket, config_open?: not socket.assigns.config_open?)}
  end

  # Components

  defp toggle_field(assigns) do
    ~H"""
    <div class={["w-1/2 flex items-center", if(@disabled, do: "opacity-50")]}>
      <.toggle_button
        described_by={@hint && "#{@feature}-hint"}
        disabled={@disabled}
        enabled={@enabled}
        feature={@feature}
        label={@label}
        myself={@myself}
      />

      <span class="ml-2 font-medium text-sm text-gray-700 dark:text-gray-300">{@label}</span>

      <span
        :if={@hint}
        id={"#{@feature}-hint"}
        data-title={@hint}
        phx-hook="Tippy"
        class="ml-1 flex items-center"
        tabindex="0"
      >
        <Icons.icon name="icon-info-circle" class="w-4 h-4 text-gray-400 dark:text-gray-500" />
        <span class="sr-only">{@hint}</span>
      </span>
    </div>
    """
  end

  attr :described_by, :string, default: nil
  attr :disabled, :boolean, required: true
  attr :enabled, :boolean, required: true
  attr :feature, :string, required: true
  attr :label, :string, required: true
  attr :myself, :any, required: true

  defp toggle_button(assigns) do
    ~H"""
    <button
      class={[
        "relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full cursor-pointer",
        "transition-colors ease-in-out duration-200",
        "focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-800",
        "disabled:cursor-not-allowed",
        if(@enabled, do: "bg-blue-500", else: "bg-gray-300 dark:bg-gray-600")
      ]}
      role="switch"
      aria-checked={to_string(@enabled)}
      aria-describedby={@described_by}
      aria-label={@label}
      disabled={@disabled}
      id={"toggle-#{@feature}"}
      phx-target={@myself}
      phx-click="toggle-feature"
      phx-value-feature={@feature}
      type="button"
    >
      <span class={"#{if @enabled, do: "translate-x-5", else: "translate-x-0"} pointer-events-none relative inline-block h-5 w-5 rounded-full bg-white shadow transform ring-0 transition ease-in-out duration-200"}>
        <span
          class={"#{if @enabled, do: "opacity-0 ease-out duration-100", else: "opacity-100 ease-in duration-200"} absolute inset-0 h-full w-full flex items-center justify-center transition-opacity"}
          aria-hidden="true"
        >
          <Icons.icon name="icon-x-mark" class="h-3 w-3 text-gray-400" />
        </span>
        <span
          class={"#{if @enabled, do: "opacity-100 ease-in duration-200", else: "opacity-0 ease-out duration-100"} absolute inset-0 h-full w-full flex items-center justify-center transition-opacity"}
          aria-hidden="true"
        >
          <Icons.icon name="icon-check" class="h-3 w-3 text-blue-500" />
        </span>
      </span>
    </button>
    """
  end

  defp panel_heading(assigns) do
    assigns = assign_new(assigns, :inner_block, fn -> [] end)

    ~H"""
    <div class="flex items-center justify-between mb-4">
      <h3 class="flex items-center">
        <Icons.icon name={@icon} class="w-5 h-5 mr-1 text-gray-500 dark:text-gray-400" />
        <span class="text-base font-medium">{@title}</span>
        <span id={@id} data-title={@hint} phx-hook="Tippy" class="ml-1 flex items-center" tabindex="0">
          <Icons.icon name="icon-info-circle" class="w-4 h-4 text-gray-400 dark:text-gray-500" />
          <span class="sr-only">{@hint}</span>
        </span>
      </h3>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp requires_pro(assigns) do
    ~H"""
    <p class="text-sm text-gray-500 dark:text-gray-400">
      Available with the Pro engine.
      <a
        rel="requires-pro"
        href="https://oban.pro/docs/pro/Oban.Pro.Engine.html"
        target="_blank"
        class="inline-flex items-center gap-0.5 font-medium text-gray-600 dark:text-gray-300 hover:text-blue-500 dark:hover:text-blue-400 hover:underline"
      >
        Learn more <Icons.icon name="icon-arrow-top-right-on-square" class="w-3 h-3" />
      </a>
    </p>
    """
  end

  attr :id, :string, required: true
  attr :error, :string, default: nil
  attr :class, :string, default: nil

  defp form_error(assigns) do
    ~H"""
    <p
      :if={@error}
      id={@id}
      role="alert"
      class={["text-sm text-red-600 dark:text-red-400", @class]}
    >
      {@error}
    </p>
    """
  end

  attr :label, :string, required: true
  attr :locked, :boolean, required: true
  attr :disabled, :boolean, required: true
  attr :confirm, :any, default: nil

  defp submit_input(assigns) do
    ~H"""
    <div class="flex items-center justify-end mt-4 space-x-2">
      <Icons.icon
        :if={@locked}
        name="icon-lock-closed"
        class="w-5 h-5 text-gray-600 dark:text-gray-400"
      />

      <button
        class={primary_button()}
        data-confirm={@confirm || nil}
        disabled={@disabled}
        type="submit"
      >
        {@label}
      </button>
    </div>
    """
  end

  defp primary_button do
    "px-4 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-gray-900 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
  end

  # JS Functions

  defp toggle_instances(myself) do
    %JS{}
    |> JS.toggle(to: "#instances-content", in: "fade-in-scale", out: "fade-out-scale")
    |> JS.add_class("rotate-90", to: "#instances-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#instances-chevron.rotate-90")
    |> JS.push("toggle-instances", target: myself)
  end

  defp toggle_config(myself) do
    %JS{}
    |> JS.toggle(to: "#config-content", in: "fade-in-scale", out: "fade-out-scale")
    |> JS.add_class("rotate-90", to: "#config-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#config-chevron.rotate-90")
    |> JS.push("toggle-config", target: myself)
  end

  # Helpers

  defp put_paused(socket, paused?) do
    checks = Enum.map(socket.assigns.checks, &Map.put(&1, "paused", paused?))
    queue_struct = %Queue{name: socket.assigns.queue, checks: checks}

    assign(socket, checks: checks, queue_struct: queue_struct)
  end

  defp stop_confirm(queue, checks) do
    nodes = count_phrase(length(checks), "node")

    case executing_count(checks) do
      0 ->
        "Stop the #{queue} queue on #{nodes}? It can't be restarted from the dashboard."

      count ->
        "Stop the #{queue} queue on #{nodes}? #{count_phrase(count, "executing job")} will finish first, but the queue can't be restarted from the dashboard."
    end
  end

  defp count_phrase(1, noun), do: "1 #{noun}"
  defp count_phrase(count, noun), do: "#{count} #{noun}s"

  defp local_limit([]), do: 0

  defp local_limit(checks) do
    checks
    |> Enum.map(& &1["local_limit"])
    |> Enum.max()
  end

  defp global_allowed(checks) do
    checks
    |> Enum.map(& &1["global_limit"])
    |> Enum.filter(&is_map/1)
    |> Enum.find_value(& &1["allowed"])
  end

  defp global_burst(checks) do
    checks
    |> Enum.map(& &1["global_limit"])
    |> Enum.filter(&is_map/1)
    |> Enum.find_value(& &1["burst"])
    |> Kernel.==(true)
  end

  defp global_per_node(checks) do
    checks
    |> Enum.map(& &1["global_limit"])
    |> Enum.filter(&is_map/1)
    |> Enum.find_value(& &1["per_node"])
    |> Kernel.==(true)
  end

  defp rate_allowed(checks) do
    checks
    |> Enum.map(& &1["rate_limit"])
    |> Enum.filter(&is_map/1)
    |> Enum.find_value(& &1["allowed"])
  end

  defp rate_period(checks) do
    checks
    |> Enum.map(& &1["rate_limit"])
    |> Enum.filter(&is_map/1)
    |> Enum.find_value(& &1["period"])
  end

  defp partition_value(checks, parent, key) do
    checks
    |> Enum.map(& &1[parent])
    |> Enum.filter(&is_map/1)
    |> List.first()
    |> case do
      %{"partition" => %{^key => [_ | _] = value}} -> Enum.join(value, ",")
      _ -> ""
    end
  end

  defp global_unchanged?(checks, inputs) do
    inputs.global_allowed == global_allowed(checks) and
      inputs.global_burst == global_burst(checks) and
      inputs.global_per_node == global_per_node(checks) and
      inputs.global_partition_fields == partition_value(checks, "global_limit", "fields") and
      inputs.global_partition_keys == partition_value(checks, "global_limit", "keys")
  end

  defp rate_unchanged?(checks, inputs) do
    inputs.rate_allowed == rate_allowed(checks) and
      inputs.rate_period == rate_period(checks) and
      inputs.rate_partition_fields == partition_value(checks, "rate_limit", "fields") and
      inputs.rate_partition_keys == partition_value(checks, "rate_limit", "keys")
  end

  defp parse_limit(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> :error
    end
  end

  defp parse_limit(value) when is_integer(value) and value > 0, do: {:ok, value}
  defp parse_limit(_value), do: :error

  defp put_error(socket, key, fields, message) do
    errors = Map.put(socket.assigns.errors, key, message)
    invalid = Enum.uniq(fields ++ socket.assigns.invalid)

    assign(socket, errors: errors, invalid: invalid)
  end

  defp clear_error(socket, [field | _]) when field in @integer_inputs do
    key =
      case field do
        "local_limit" -> :local
        "global_allowed" -> :global
        _ -> :rate
      end

    assign(socket,
      errors: Map.delete(socket.assigns.errors, key),
      invalid: List.delete(socket.assigns.invalid, field)
    )
  end

  defp clear_error(socket, _target), do: socket

  defp maybe_split(nil), do: []

  defp maybe_split(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp maybe_add_burst(global_limit, true), do: Map.put(global_limit, :burst, true)
  defp maybe_add_burst(global_limit, false), do: global_limit

  defp maybe_add_per_node(global_limit, true), do: Map.put(global_limit, :per_node, true)
  defp maybe_add_per_node(global_limit, false), do: global_limit

  defp partition_options do
    [
      Off: "",
      Worker: "worker",
      Args: "args",
      Meta: "meta",
      "Worker + Args": "args,worker",
      "Worker + Meta": "meta,worker"
    ]
  end

  defp keyless_partition?(fields),
    do: fields not in ["args", "meta", "args,worker", "meta,worker"]

  defp local_limit_display(checks) do
    limits = Enum.map(checks, & &1["local_limit"])

    if Enum.uniq(limits) |> length() == 1 do
      List.first(limits)
    else
      "varies"
    end
  end

  defp global_limit_display(%{global_allowed: nil}), do: "—"

  defp global_limit_display(%{global_allowed: allowed, global_per_node: true}) do
    "#{allowed} per node"
  end

  defp global_limit_display(%{global_allowed: allowed}), do: "#{allowed} cluster-wide"

  defp rate_limit_display(%{rate_allowed: nil}), do: "—"

  defp rate_limit_display(%{rate_allowed: allowed, rate_period: period}) do
    "#{allowed}/#{period}s"
  end

  defp queue_history(conf, queue) do
    since = Timing.snap(System.system_time(:second), @history_by)

    opts = [
      by: @history_by,
      lookback: @history_lookback,
      filters: [queue: queue],
      since: since
    ]

    conf.name
    |> Met.timeslice(:exec_count, opts)
    |> transform_history(since)
  end

  defp transform_history(timeslice_data, since) do
    counts = Map.new(timeslice_data, fn {index, count, _group} -> {index, count} end)

    for index <- (div(@history_lookback, @history_by) - 1)..0//-1 do
      %{count: Map.get(counts, index, 0), timestamp: (since - index * @history_by) * 1000}
    end
  end

  # Pro Helpers

  defp missing_pro?(%Config{} = conf), do: not Utils.pro_engine?(conf)
end
