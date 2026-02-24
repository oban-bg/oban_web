defmodule Oban.Web.Queues.DetailComponent do
  use Oban.Web, :live_component

  import Oban.Web.FormComponents
  import Oban.Web.Helpers.QueueHelper

  alias Oban.Config
  alias Oban.Met
  alias Oban.Web.Components.Core
  alias Oban.Web.Queue
  alias Oban.Web.Queues.DetailInstanceComponent
  alias Oban.Web.Timing

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

    counts =
      Met.latest(assigns.conf.name, :full_count, group: "state", filters: [queue: assigns.queue])

    history = queue_history(assigns.conf, assigns.queue)

    socket =
      socket
      |> assign(access: assigns.access, conf: assigns.conf, queue: assigns.queue)
      |> assign(counts: counts, checks: checks, queue_struct: queue, history: history)
      |> assign(node_history: assigns[:node_history] || %{})
      |> assign_new(:instances_open?, fn -> true end)
      |> assign_new(:config_open?, fn -> false end)
      |> assign_new(:inputs, fn ->
        %{
          local_limit: local_limit(checks),
          global_allowed: global_allowed(checks),
          global_burst: global_burst(checks),
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
          <.stats_grid checks={@checks} counts={@counts} inputs={@inputs} />
        </div>
      </div>

      <.instances_section
        access={@access}
        checks={@checks}
        instances_open?={@instances_open?}
        myself={@myself}
        node_history={@node_history}
      />

      <.config_section
        access={@access}
        checks={@checks}
        conf={@conf}
        config_open?={@config_open?}
        inputs={@inputs}
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
      <button
        id="back-link"
        class="flex items-center hover:text-blue-500 cursor-pointer bg-transparent border-0 p-0"
        data-escape-back={true}
        phx-hook="HistoryBack"
        type="button"
      >
        <Icons.arrow_left class="w-5 h-5" />
        <span class="text-lg capitalize font-bold ml-2">{@queue} Queue</span>
      </button>

      <div class="flex space-x-3">
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
          confirm="Are you sure you want to stop this queue?"
          phx-target={@myself}
          phx-click="stop-queue"
        />

        <Core.icon_button
          id="detail-edit"
          icon="pencil_square"
          label="Edit"
          color="violet"
          tooltip="Edit queue configuration"
          disabled={not can?(:scale_queues, @access)}
          phx-click={scroll_to_config()}
        />
      </div>
    </div>
    """
  end

  # History Chart Component

  defp history_chart(assigns) do
    ~H"""
    <div class="group relative">
      <div
        id="queue-detail-chart"
        class="h-64 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
        phx-hook="QueueDetailChart"
        phx-update="ignore"
      >
      </div>
      <.link
        navigate={oban_path(:jobs, %{queues: @queue, state: "completed"})}
        class="absolute right-4 top-4 flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:bg-blue-100 hover:text-blue-600 dark:hover:bg-blue-900 dark:hover:text-blue-300 opacity-0 group-hover:opacity-100 transition-opacity"
      >
        View all jobs <Icons.arrow_right class="w-3 h-3" />
      </.link>
    </div>
    """
  end

  # Stats Grid Component

  defp stats_grid(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="grid grid-cols-4 gap-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-md">
        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Executing
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {executing_count(@checks)}
          </span>
        </div>

        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Available
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {integer_to_estimate(@counts["available"])}
          </span>
        </div>

        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Scheduled
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {integer_to_estimate(@counts["scheduled"])}
          </span>
        </div>

        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Retryable
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {integer_to_estimate(@counts["retryable"])}
          </span>
        </div>

        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Cancelled
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {integer_to_estimate(@counts["cancelled"])}
          </span>
        </div>

        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Discarded
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {integer_to_estimate(@counts["discarded"])}
          </span>
        </div>

        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Completed
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {integer_to_estimate(@counts["completed"])}
          </span>
        </div>

        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Started
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200">
            {started_at(@checks)}
          </span>
        </div>
      </div>

      <div class="grid grid-cols-3 gap-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-md">
        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Local Limit
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {local_limit_display(@checks)}
          </span>
        </div>

        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Global Limit
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {global_limit_display(@inputs)}
          </span>
        </div>

        <div class="flex flex-col">
          <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
            Rate Limit
          </span>
          <span class="text-base text-gray-800 dark:text-gray-200 tabular">
            {rate_limit_display(@inputs)}
          </span>
        </div>
      </div>
    </div>
    """
  end

  # Instances Section Component

  defp instances_section(assigns) do
    ~H"""
    <div id="queue-instances" class="border-t border-gray-200 dark:border-gray-700">
      <div class="px-3 py-6">
        <button
          id="instances-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
          phx-click={toggle_instances(@myself)}
        >
          <Icons.chevron_right
            id="instances-chevron"
            class={["w-5 h-5 transition-transform", if(@instances_open?, do: "rotate-90")]}
          />
          <span class="font-semibold">
            Instances
            <span class="text-gray-400 font-normal">
              ({length(@checks)})
            </span>
          </span>
        </button>

        <div id="instances-content" class={["mt-3", unless(@instances_open?, do: "hidden")]}>
          <table class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700 border border-gray-200 dark:border-gray-700 rounded-md overflow-hidden">
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
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
          phx-click={toggle_config(@myself)}
        >
          <Icons.chevron_right
            id="config-chevron"
            class={["w-5 h-5 transition-transform", if(@config_open?, do: "rotate-90")]}
          />
          <span class="font-semibold">Edit Configuration</span>
        </button>

        <div id="config-content" class={["mt-3", unless(@config_open?, do: "hidden")]}>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 bg-gray-50 dark:bg-gray-800 rounded-md p-4">
            <form
              id="local-form"
              phx-target={@myself}
              phx-change="form-change"
              phx-submit="local-submit"
            >
              <h3 class="flex items-center mb-4">
                <Icons.map_pin class="w-5 h-5 mr-1 text-gray-500" />
                <span class="text-base font-medium">Local Limit</span>
              </h3>

              <.form_field
                label="Limit"
                name="local_limit"
                value={@inputs.local_limit}
                type="number"
                disabled={not can?(:scale_queues, @access)}
              />

              <.submit_input
                locked={not can?(:scale_queues, @access)}
                disabled={
                  @inputs.local_limit == local_limit(@checks) or not can?(:scale_queues, @access)
                }
                label="Scale"
              />
            </form>

            <form
              class="p-4 bg-violet-50 dark:bg-violet-950/30 rounded-md ring-1 ring-violet-200 dark:ring-violet-800"
              id="global-form"
              phx-change="form-change"
              phx-submit="global-update"
              phx-target={@myself}
            >
              <div class="flex items-center justify-between mb-4">
                <h3 class="flex items-center">
                  <Icons.globe class="w-5 h-5 mr-1 text-gray-500" />
                  <span class="text-base font-medium">Global Limit</span>
                  <span
                    id="global-limit-info"
                    data-title="Limits total concurrent jobs across all nodes"
                    phx-hook="Tippy"
                    class="ml-1"
                  >
                    <Icons.info_circle class="w-4 h-4 text-gray-400 dark:text-gray-500" />
                  </span>
                </h3>

                <.toggle_button
                  disabled={not can?(:scale_queues, @access) or missing_pro?(@conf)}
                  enabled={not is_nil(@inputs.global_allowed)}
                  feature="global"
                  myself={@myself}
                />
              </div>

              <div class="flex w-full mb-6">
                <div class="w-1/2 pr-1.5">
                  <.form_field
                    label="Allowed"
                    name="global_allowed"
                    value={@inputs.global_allowed}
                    type="number"
                    disabled={
                      not can?(:scale_queues, @access) or is_nil(@inputs.global_allowed) or
                        missing_pro?(@conf)
                    }
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
                    disabled={
                      not can?(:scale_queues, @access) or is_nil(@inputs.global_allowed) or
                        missing_pro?(@conf)
                    }
                  />
                </div>

                <div class="w-1/2">
                  <label for="global_partition_keys" class="block font-medium text-sm mb-2">
                    Partition Keys
                  </label>

                  <input
                    class="block w-full font-mono text-sm py-2 shadow-sm border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 disabled:opacity-50 rounded-md focus:ring-blue-400 focus:border-blue-400"
                    disabled={
                      keyless_partition?(@inputs.global_partition_fields) or
                        not can?(:scale_queues, @access) or missing_pro?(@conf)
                    }
                    id="global_partition_keys"
                    name="global_partition_keys"
                    type="text"
                    value={@inputs.global_partition_keys}
                  />
                </div>
              </div>

              <div class="mb-4">
                <.checkbox_field
                  label="Burst"
                  name="global_burst"
                  checked={@inputs.global_burst}
                  disabled={
                    not can?(:scale_queues, @access) or is_nil(@inputs.global_allowed) or
                      is_nil(@inputs.global_partition_fields) or missing_pro?(@conf)
                  }
                  hint="Allow partitions to exceed limit when capacity available"
                />
              </div>

              <div class="flex flex-col items-end gap-2">
                <.submit_input
                  locked={not can?(:scale_queues, @access)}
                  disabled={
                    global_unchanged?(@checks, @inputs) or not can?(:scale_queues, @access) or
                      missing_pro?(@conf)
                  }
                  label="Apply"
                />
                <a
                  :if={missing_pro?(@conf)}
                  rel="requires-pro"
                  href="https://oban.pro/docs/pro/Oban.Pro.Engines.Smart.html"
                  target="_blank"
                  class="text-xs text-gray-500 dark:text-gray-400 hover:underline"
                >
                  Requires Smart Engine
                  <Icons.arrow_top_right_on_square class="w-3 h-3 inline-block" />
                </a>
              </div>
            </form>

            <form
              class="p-4 bg-violet-50 dark:bg-violet-950/30 rounded-md ring-1 ring-violet-200 dark:ring-violet-800"
              id="rate-limit-form"
              phx-change="form-change"
              phx-submit="rate-limit-update"
              phx-target={@myself}
            >
              <div class="flex items-center justify-between mb-4">
                <h3 class="flex items-center">
                  <Icons.arrow_trending_down class="w-5 h-5 mr-1 text-gray-500" />
                  <span class="text-base font-medium">Rate Limit</span>
                  <span
                    id="rate-limit-info"
                    data-title="Limits jobs executed within a time window"
                    phx-hook="Tippy"
                    class="ml-1"
                  >
                    <Icons.info_circle class="w-4 h-4 text-gray-400 dark:text-gray-500" />
                  </span>
                </h3>

                <.toggle_button
                  disabled={not can?(:scale_queues, @access) or missing_pro?(@conf)}
                  enabled={not is_nil(@inputs.rate_allowed)}
                  feature="rate-limit"
                  myself={@myself}
                />
              </div>

              <div class="flex w-full space-x-3 mb-6">
                <div class="w-1/2">
                  <.form_field
                    label="Allowed"
                    name="rate_allowed"
                    value={@inputs.rate_allowed}
                    type="number"
                    disabled={
                      not can?(:scale_queues, @access) or is_nil(@inputs.rate_allowed) or
                        missing_pro?(@conf)
                    }
                  />
                </div>

                <div class="w-1/2">
                  <.form_field
                    label="Period"
                    name="rate_period"
                    value={@inputs.rate_period}
                    type="number"
                    disabled={
                      not can?(:scale_queues, @access) or is_nil(@inputs.rate_allowed) or
                        missing_pro?(@conf)
                    }
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
                    disabled={
                      not can?(:scale_queues, @access) or is_nil(@inputs.rate_allowed) or
                        missing_pro?(@conf)
                    }
                  />
                </div>

                <div class="w-1/2">
                  <label for="rate_partition_keys" class="block font-medium text-sm mb-2">
                    Partition Keys
                  </label>

                  <input
                    class="block w-full font-mono text-sm py-2 shadow-sm border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 disabled:opacity-50 rounded-md focus:ring-blue-400 focus:border-blue-400"
                    disabled={
                      keyless_partition?(@inputs.rate_partition_fields) or
                        not can?(:scale_queues, @access) or missing_pro?(@conf)
                    }
                    id="rate_partition_keys"
                    name="rate_partition_keys"
                    type="text"
                    value={@inputs.rate_partition_keys}
                  />
                </div>
              </div>

              <div class="flex flex-col items-end gap-2 mt-4">
                <.submit_input
                  locked={not can?(:scale_queues, @access)}
                  disabled={
                    rate_unchanged?(@checks, @inputs) or not can?(:scale_queues, @access) or
                      missing_pro?(@conf)
                  }
                  label="Apply"
                />
                <a
                  :if={missing_pro?(@conf)}
                  rel="requires-pro"
                  href="https://oban.pro/docs/pro/Oban.Pro.Engines.Smart.html"
                  target="_blank"
                  class="text-xs text-gray-500 dark:text-gray-400 hover:underline"
                >
                  Requires Smart Engine
                  <Icons.arrow_top_right_on_square class="w-3 h-3 inline-block" />
                </a>
              </div>
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

  def handle_event("form-change", %{"_target" => ["global_burst"]} = params, socket) do
    burst = params["global_burst"] == "true"
    inputs = %{socket.assigns.inputs | global_burst: burst}

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("form-change", params, socket) do
    inputs =
      for {key, val} <- params, key in @integer_inputs, reduce: socket.assigns.inputs do
        acc ->
          case Integer.parse(val) do
            {int, _} when int > 0 ->
              %{acc | String.to_existing_atom(key) => int}

            _ ->
              acc
          end
      end

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("local-submit", params, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    limit = String.to_integer(params["local_limit"])

    send(self(), {:scale_queue, socket.assigns.queue, limit: limit})

    inputs = %{socket.assigns.inputs | local_limit: limit}

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("global-update", params, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    inputs =
      if is_nil(params["global_allowed"]) do
        send(self(), {:scale_queue, socket.assigns.queue, global_limit: nil})

        socket.assigns.inputs
        |> Map.replace!(:global_allowed, nil)
        |> Map.replace!(:global_burst, false)
        |> Map.replace!(:global_partition_fields, nil)
        |> Map.replace!(:global_partition_keys, nil)
      else
        allowed = String.to_integer(params["global_allowed"])
        fields = maybe_split(params["global_partition_fields"])
        keys = maybe_split(params["global_partition_keys"])
        burst = params["global_burst"] == "true"

        global_limit =
          case fields do
            [] ->
              %{allowed: allowed}

            ["worker"] ->
              %{allowed: allowed, partition: [fields: fields]}
              |> maybe_add_burst(burst)

            _ ->
              %{allowed: allowed, partition: [fields: fields, keys: keys]}
              |> maybe_add_burst(burst)
          end

        send(self(), {:scale_queue, socket.assigns.queue, global_limit: global_limit})

        socket.assigns.inputs
        |> Map.replace!(:global_allowed, allowed)
        |> Map.replace!(:global_burst, burst)
        |> Map.replace!(:global_partition_fields, Enum.join(fields, ","))
        |> Map.replace!(:global_partition_keys, Enum.join(keys, ","))
      end

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("rate-limit-update", params, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    inputs =
      if is_nil(params["rate_allowed"]) do
        send(self(), {:scale_queue, socket.assigns.queue, rate_limit: nil})

        socket.assigns.inputs
        |> Map.replace!(:rate_allowed, nil)
        |> Map.replace!(:rate_period, nil)
        |> Map.replace!(:rate_partition_fields, nil)
        |> Map.replace!(:rate_partition_keys, nil)
      else
        allowed = String.to_integer(params["rate_allowed"])
        period = String.to_integer(params["rate_period"])
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

        socket.assigns.inputs
        |> Map.replace!(:rate_allowed, allowed)
        |> Map.replace!(:rate_period, period)
        |> Map.replace!(:rate_partition_fields, Enum.join(fields, ","))
        |> Map.replace!(:rate_partition_keys, Enum.join(keys, ","))
      end

    {:noreply, assign(socket, inputs: inputs)}
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
        |> Map.put(:global_partition_fields, nil)
        |> Map.put(:global_partition_keys, nil)
      end

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
        |> Map.put(:rate_partition_fields, nil)
        |> Map.put(:rate_partition_keys, nil)
      end

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("pause-queue", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    send(self(), {:pause_queue, socket.assigns.queue})

    {:noreply, socket}
  end

  def handle_event("resume-queue", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    send(self(), {:resume_queue, socket.assigns.queue})

    {:noreply, socket}
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

  defp toggle_button(assigns) do
    ~H"""
    <button
      class="bg-gray-200 dark:bg-gray-800 relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full cursor-pointer transition-colors ease-in-out duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500"
      role="switch"
      aria-checked="false"
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
          <Icons.x_mark class="h-3 w-3 text-gray-400" />
        </span>
        <span
          class={"#{if @enabled, do: "opacity-100 ease-in duration-200", else: "opacity-0 ease-out duration-100"} absolute inset-0 h-full w-full flex items-center justify-center transition-opacity"}
          aria-hidden="true"
        >
          <Icons.check class="h-3 w-3 text-blue-500" />
        </span>
      </span>
    </button>
    """
  end

  defp submit_input(assigns) do
    ~H"""
    <div class="flex items-center justify-end mt-4 space-x-2">
      <%= if @locked do %>
        <Icons.lock_closed class="w-5 h-5 text-gray-600 dark:text-gray-400" />
      <% end %>

      <button
        class={"block px-3 py-2 font-medium text-sm text-gray-600 dark:text-gray-100 bg-gray-300 dark:bg-blue-950 dark:bg-opacity-25 hover:bg-blue-500 hover:text-white dark:hover:bg-blue-500 dark:hover:text-white rounded-md shadow-sm #{if @disabled, do: "opacity-30 pointer-events-none"}"}
        disabled={@disabled}
        type="submit"
      >
        {@label}
      </button>
    </div>
    """
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

  defp scroll_to_config do
    %JS{}
    |> JS.show(to: "#config-content", transition: "fade-in-scale")
    |> JS.add_class("rotate-90", to: "#config-chevron")
    |> JS.focus(to: "#local-form input")
  end

  # Helpers

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
      _ -> nil
    end
  end

  defp global_unchanged?(checks, inputs) do
    inputs.global_allowed == global_allowed(checks) and
      inputs.global_burst == global_burst(checks) and
      inputs.global_partition_fields == partition_value(checks, "global_limit", "fields") and
      inputs.global_partition_keys == partition_value(checks, "global_limit", "keys")
  end

  defp rate_unchanged?(checks, inputs) do
    inputs.rate_allowed == rate_allowed(checks) and
      inputs.rate_period == rate_period(checks) and
      inputs.rate_partition_fields == partition_value(checks, "rate_limit", "fields") and
      inputs.rate_partition_keys == partition_value(checks, "rate_limit", "keys")
  end

  defp maybe_split(""), do: []
  defp maybe_split(nil), do: []
  defp maybe_split(value) when is_binary(value), do: String.split(value, ",")

  defp maybe_add_burst(global_limit, true), do: Map.put(global_limit, :burst, true)
  defp maybe_add_burst(global_limit, false), do: global_limit

  defp partition_options do
    [
      Off: nil,
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
  defp global_limit_display(%{global_allowed: allowed}), do: allowed

  defp rate_limit_display(%{rate_allowed: nil}), do: "—"

  defp rate_limit_display(%{rate_allowed: allowed, rate_period: period}) do
    "#{allowed}/#{period}s"
  end

  defp queue_history(conf, queue) do
    by = 5
    since = Timing.snap(System.system_time(:second), by)

    conf.name
    |> Met.timeslice(:exec_count, by: by, lookback: 600, filters: [queue: queue], since: since)
    |> transform_history(since, by)
  end

  defp transform_history(timeslice_data, since, by) do
    timeslice_data
    |> Enum.map(fn {index, count, _group} ->
      timestamp = (since - index * by) * 1000

      %{count: count, timestamp: timestamp}
    end)
    |> Enum.sort_by(& &1.timestamp)
  end

  # Pro Helpers

  defp missing_pro?(%Config{engine: engine}) do
    engine in [Oban.Queue.BasicEngine, Oban.Engines.Basic]
  end
end
