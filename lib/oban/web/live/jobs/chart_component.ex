defmodule Oban.Web.Jobs.ChartComponent do
  use Oban.Web, :live_component

  alias Oban.Met
  alias Oban.Web.Colors
  alias Oban.Web.Components.Core
  alias Oban.Web.Timing

  # Keep failure states at the baseline where spikes are easiest to spot, so the bulk of completed
  # jobs stack on top.
  @stack_order ~w(discarded retryable cancelled completed executing available scheduled suspended)

  @storable ~w(group ntile period series visible)a

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, hidden: MapSet.new(), last_os_time: 0, max_cols: 100, max_data: 7)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    default_series = hd(series())

    socket =
      socket
      |> assign(conf: assigns.conf, params: assigns.params)
      |> assign_new(:group, fn -> init_lazy(:group, assigns, hd(groups())) end)
      |> assign_new(:ntile, fn -> init_lazy(:ntile, assigns, ntile_for_series(default_series)) end)
      |> assign_new(:period, fn -> init_lazy(:period, assigns, hd(periods())) end)
      |> assign_new(:series, fn -> init_lazy(:series, assigns, default_series) end)
      |> assign_new(:visible, fn -> init_lazy(:visible, assigns, true) end)
      |> assign_new(:datasets, fn -> [] end)
      |> assign_new(:truncated, fn -> 0 end)

    socket =
      if socket.assigns.visible do
        step = period_to_step(socket.assigns.period)
        os_time = Timing.snap(assigns.os_time, step)

        socket =
          socket
          |> assign(last_os_time: os_time)
          |> assign_datasets(os_time)

        push_event(socket, "chart-change", chart_payload(socket.assigns, [:group, :series]))
      else
        socket
      end

    {:ok, socket}
  end

  defp init_lazy(key, %{init_state: init_state}, default) do
    Map.get(init_state, "oban:chart-#{key}", default)
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="w-full bg-white dark:bg-gray-900 rounded-md shadow-md mb-3">
      <div class="flex items-center justify-between p-3">
        <div id="chart-h" class="flex items-center text-gray-900 dark:text-gray-200">
          <button
            id="chart-toggle"
            type="button"
            class="rounded-md focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
            aria-controls="chart-body"
            aria-expanded={to_string(@visible)}
            aria-label="Toggle chart"
            data-title="Toggle chart"
            phx-click={toggle_chart(@myself)}
            phx-hook="Tippy"
          >
            <Icons.icon
              name="icon-chevron-right"
              id="chart-chevron"
              class={[
                "w-5 h-5 mr-2 transition-transform",
                if(@visible, do: "rotate-90")
              ]}
            />
          </button>

          <h3 class="text-base font-semibold">
            {metric_label(@series)}
          </h3>

          <span class="text-gray-600 dark:text-gray-400 font-light ml-1">
            ({subtitle(@series, @ntile, @period, @group)})
          </span>

          <span
            :if={@params |> params_to_filters() |> Enum.any?()}
            id="chart-filtered-alert"
            class="w-3 h-3 ml-1 bg-violet-500 rounded-full"
            data-title={"Filtered by #{params_to_filters_list(@params)}"}
            phx-hook="Tippy"
          ></span>
        </div>

        <div id="chart-c" class="flex space-x-2">
          <.chart_dropdown
            disabled={not @visible}
            icon="icon-chart-bar-square"
            myself={@myself}
            name="series"
            options={series()}
            selected={@series}
            title="Change metric series"
          />

          <.chart_dropdown
            disabled={not @visible}
            icon="icon-clock"
            myself={@myself}
            name="period"
            options={periods()}
            selected={@period}
            title="Change slice period"
          />

          <.chart_dropdown
            disabled={not @visible}
            icon="icon-rectangle-group"
            myself={@myself}
            name="group"
            options={groups_for_series(@series)}
            selected={@group}
            title="Change metric grouping"
          />

          <.chart_dropdown
            disabled={not @visible or @series in ~w(exec_count full_count)}
            icon="icon-percent-square"
            myself={@myself}
            name="ntile"
            options={ntiles()}
            selected={@ntile}
            title="Change percentile"
          />
        </div>
      </div>

      <div id="chart-body" class={unless(@visible, do: "hidden")}>
        <div
          id="chart"
          class="w-full relative cursor-crosshair pl-5 pr-3 h-45"
          role="img"
          aria-label={chart_label(@datasets, @series, @ntile, @period, @group)}
        >
          <canvas id="chart-canvas" phx-hook="JobsChart" phx-target={@myself} phx-update="ignore"></canvas>

          <p
            :if={@datasets == []}
            id="chart-empty"
            aria-hidden="true"
            class="absolute inset-0 flex items-center justify-center text-sm text-gray-500 dark:text-gray-400"
          >
            {empty_label(@series, @period)}
          </p>
        </div>

        <%!-- The sidebar already maps every state to its color, so only other groupings need a key. --%>
        <div
          :if={@datasets != [] and @group != "state"}
          id="chart-legend"
          role="group"
          aria-label="Toggle chart series"
          class="flex flex-wrap items-center gap-x-4 gap-y-1 px-5 pb-3 text-xs"
        >
          <.legend_item
            :for={dataset <- @datasets}
            dataset={dataset}
            group={@group}
            myself={@myself}
            pressed={not MapSet.member?(@hidden, dataset.label)}
            truncated={@truncated}
          />

          <span
            :if={@truncated > 0 and @series in ~w(exec_time wait_time)}
            class="text-gray-400 dark:text-gray-500"
          >
            +{@truncated} more
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :dataset, :map, required: true
  attr :group, :string, required: true
  attr :myself, :any, required: true
  attr :pressed, :boolean, required: true
  attr :truncated, :integer, required: true

  defp legend_item(assigns) do
    {dot_class, label_class} =
      if assigns.pressed do
        {assigns.dataset.dot_class, "text-gray-600 dark:text-gray-400"}
      else
        {"bg-gray-300 dark:bg-gray-600", "text-gray-400 dark:text-gray-500"}
      end

    assigns = assign(assigns, dot_class: dot_class, label_class: label_class)

    ~H"""
    <button
      type="button"
      id={"legend-#{@dataset.label}"}
      class="flex items-center gap-x-1.5 rounded-md cursor-pointer hover:text-gray-900 dark:hover:text-gray-100
      focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
      aria-pressed={to_string(@pressed)}
      data-title={if @dataset.label == "other", do: "#{@truncated} more #{@group}s"}
      phx-click="toggle-series"
      phx-hook={if @dataset.label == "other", do: "Tippy"}
      phx-target={@myself}
      phx-value-label={@dataset.label}
    >
      <span aria-hidden="true" class={["w-2 h-2 rounded-full", @dot_class]} />
      <span class={@label_class}>{@dataset.label}</span>
    </button>
    """
  end

  attr :disabled, :boolean, default: false
  attr :icon, :string, required: true
  attr :myself, :any, required: true
  attr :name, :string, required: true
  attr :options, :list, required: true
  attr :selected, :string, required: true
  attr :title, :string, required: true

  defp chart_dropdown(assigns) do
    ~H"""
    <Core.dropdown_menu
      id={@name}
      aria_label={@title}
      disabled={@disabled}
      title={@title}
      toggle_class="hidden md:flex h-9 w-9 items-center justify-center text-gray-500 dark:text-gray-400
      enabled:hover:text-gray-700 dark:enabled:hover:text-gray-200
      enabled:hover:bg-black/5 dark:enabled:hover:bg-white/5
      disabled:text-gray-400 disabled:dark:text-gray-500"
    >
      <:toggle>
        <Icons.icon name={@icon} />
      </:toggle>

      <.chart_option
        :for={value <- @options}
        myself={@myself}
        name={@name}
        selected={@selected}
        value={value}
      />
    </Core.dropdown_menu>
    """
  end

  attr :myself, :any, required: true
  attr :name, :string, required: true
  attr :selected, :string, required: true
  attr :value, :string, required: true

  defp chart_option(assigns) do
    {class, label_class} =
      if assigns.selected == assigns.value do
        {"text-blue-500 dark:text-blue-400", "text-blue-500 dark:text-blue-400"}
      else
        {"text-gray-500 dark:text-gray-400", "text-gray-800 dark:text-gray-200"}
      end

    assigns = assign(assigns, class: class, label_class: label_class)

    ~H"""
    <Core.menu_option
      class={["select-none", @class]}
      id={"select-#{@name}-#{@value}"}
      selected={@value == @selected}
      phx-click={
        "select-#{@name}"
        |> JS.push(target: @myself)
        |> Core.close_menu(@name)
        |> JS.focus(to: "##{@name}-menu-toggle")
      }
      phx-value-choice={@value}
    >
      <%= if @value == @selected do %>
        <Icons.icon name="icon-check" class="w-5 h-5 shrink-0" />
      <% else %>
        <span class="block w-5 h-5 shrink-0"></span>
      <% end %>

      <span class={["capitalize", @label_class]}>{String.replace(@value, "_", " ")}</span>
    </Core.menu_option>
    """
  end

  # Data

  defp assign_datasets(socket, os_time) do
    {datasets, truncated} = datasets(os_time, socket.assigns)

    assign(socket, datasets: datasets, truncated: truncated)
  end

  defp datasets(os_time, assigns) do
    step = period_to_step(assigns.period)
    cols = assigns.max_cols
    sy_time = Timing.snap(System.system_time(:second), step)

    opts = [
      by: step,
      filters: params_to_filters(assigns.params),
      group: assigns.group,
      lookback: cols * step,
      operation: ntile_to_operation(assigns.ntile),
      since: sy_time
    ]

    {grouped, truncated} =
      assigns.conf.name
      |> Met.timeslice(String.to_existing_atom(assigns.series), opts)
      |> Enum.group_by(&elem(&1, 2), &Tuple.delete_at(&1, 2))
      |> Enum.sort_by(fn {_label, slices} -> total(slices) end, :desc)
      |> limit_groups(assigns)

    colors = group_colors(grouped, assigns.group)

    datasets =
      for {label, slices} <- grouped do
        {hex, dot_class} = Map.fetch!(colors, label)

        %{
          label: label,
          hex: hex,
          dot_class: dot_class,
          data: interpolate(slices, cols, step, os_time)
        }
      end

    {order_datasets(datasets, assigns.group), truncated}
  end

  # Every state fits, so only other groupings are capped. Counts fold the remainder into an
  # "other" series so the stack height stays truthful; percentiles can't be combined, so those
  # series are dropped and the legend says how many.
  defp limit_groups(grouped, %{group: "state"}), do: {grouped, 0}

  defp limit_groups(grouped, assigns) do
    {kept, rest} = Enum.split(grouped, assigns.max_data)

    cond do
      rest == [] ->
        {kept, 0}

      assigns.series in ~w(exec_count full_count) ->
        other =
          rest
          |> Enum.flat_map(fn {_label, slices} -> slices end)
          |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
          |> Enum.map(fn {index, values} -> {index, Enum.sum(values)} end)

        {kept ++ [{"other", other}], length(rest)}

      true ->
        {kept, length(rest)}
    end
  end

  defp group_colors(grouped, "state") do
    Map.new(grouped, fn {label, _slices} ->
      {label, {Colors.state_hex(label), Colors.state_bg_class(label)}}
    end)
  end

  defp group_colors(grouped, _group) do
    labels = for {label, _slices} <- grouped, label != "other", do: label

    labels
    |> Colors.series_colors()
    |> Map.put("other", :gray)
    |> Map.new(fn {label, name} ->
      {label, {Colors.series_hex(name), Colors.series_bg_class(name)}}
    end)
  end

  defp order_datasets(datasets, "state") do
    Enum.sort_by(datasets, &Enum.find_index(@stack_order, fn state -> state == &1.label end))
  end

  defp order_datasets(datasets, _group), do: datasets

  defp total(slices), do: Enum.reduce(slices, 0, &(elem(&1, 1) + &2))

  defp interpolate(slices, cols, step, time) do
    lookup = Map.new(slices)

    for index <- 0..(cols - 1) do
      x = time - step * index
      y = Map.get(lookup, index, nil)

      %{x: to_string(x), y: y}
    end
  end

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("select-group", %{"choice" => group}, socket) do
    {:noreply, push_change(socket, group: group, hidden: MapSet.new())}
  end

  def handle_event("select-ntile", %{"choice" => ntile}, socket) do
    {:noreply, push_change(socket, ntile: ntile)}
  end

  def handle_event("select-period", %{"choice" => period}, socket) do
    {:noreply, push_change(socket, period: period)}
  end

  def handle_event("select-series", %{"choice" => series}, socket) do
    assigns =
      cond do
        series == "full_count" and socket.assigns.group in ~w(node worker) ->
          [ntile: "max", group: "state", series: series]

        series == "full_count" ->
          [ntile: "max", series: series]

        series in ~w(exec_time wait_time) ->
          [ntile: "p95", series: series]

        true ->
          [ntile: "sum", series: series]
      end

    {:noreply, push_change(socket, [hidden: MapSet.new()] ++ assigns)}
  end

  def handle_event("toggle-series", %{"label" => label}, socket) do
    hidden = socket.assigns.hidden

    hidden =
      if MapSet.member?(hidden, label),
        do: MapSet.delete(hidden, label),
        else: MapSet.put(hidden, label)

    {:noreply, push_change(socket, hidden: hidden)}
  end

  def handle_event("chart-select", %{"label" => "other"}, socket) do
    {:noreply, socket}
  end

  def handle_event("chart-select", %{"label" => label}, socket) do
    %{group: group, params: params} = socket.assigns

    {:noreply, push_patch(socket, to: select_path(group, label, params))}
  end

  def handle_event("toggle-visible", _params, socket) do
    socket =
      if socket.assigns.visible do
        push_change(socket, visible: false)
      else
        push_change(socket, visible: true)
      end

    {:noreply, socket}
  end

  defp push_change(socket, change) do
    for {key, value} <- change, key in @storable do
      send(self(), {:store_state, "chart-#{key}", value})
    end

    socket =
      socket
      |> assign(change)
      |> assign_datasets(socket.assigns.last_os_time)

    push_event(socket, "chart-change", chart_payload(socket.assigns, []))
  end

  defp chart_payload(assigns, only) do
    payload = %{
      group: assigns.group,
      hidden: MapSet.to_list(assigns.hidden),
      ntile: assigns.ntile,
      period: assigns.period,
      points: Enum.map(assigns.datasets, &Map.take(&1, [:label, :hex, :data])),
      series: assigns.series,
      visible: assigns.visible
    }

    if only == [], do: payload, else: Map.take(payload, [:hidden, :points | only])
  end

  defp select_path("state", label, params) do
    oban_path(:jobs, Map.put(params, :state, label))
  end

  defp select_path(group, label, params) do
    key =
      case group do
        "node" -> :nodes
        "queue" -> :queues
        "worker" -> :workers
      end

    oban_path(:jobs, Map.put(params, key, [label]))
  end

  # Lookups

  def groups, do: ~w(state queue node worker)
  def ntiles, do: ~w(max p99 p95 p75 p50)
  def periods, do: ~w(1s 5s 10s 30s 1m 2m)
  def series, do: ~w(exec_count full_count exec_time wait_time)

  defp groups_for_series("full_count"), do: ~w(state queue)
  defp groups_for_series(_series), do: groups()

  defp ntile_for_series(series) when series in ~w(exec_time wait_time), do: "p95"
  defp ntile_for_series(_series), do: "sum"

  defp metric_label("exec_count"), do: "Executed Count"
  defp metric_label("full_count"), do: "Full Count"
  defp metric_label("exec_time"), do: "Execution Time"
  defp metric_label("wait_time"), do: "Queue Time"

  defp metric_noun("exec_count"), do: "executions"
  defp metric_noun("full_count"), do: "jobs"
  defp metric_noun("exec_time"), do: "execution times"
  defp metric_noun("wait_time"), do: "queue times"

  defp subtitle(series, ntile, period, group) when series in ~w(exec_time wait_time) do
    "#{ntile} · #{period} by #{String.capitalize(group)}"
  end

  defp subtitle(_series, _ntile, period, group) do
    "#{period} by #{String.capitalize(group)}"
  end

  defp chart_label([], series, _ntile, period, _group), do: empty_label(series, period)

  defp chart_label(_datasets, series, ntile, period, group) do
    "#{metric_label(series)}, #{subtitle(series, ntile, period, group)}"
  end

  defp empty_label(series, period) do
    "No #{metric_noun(series)} recorded in the last #{window_label(period)}"
  end

  defp window_label(period) do
    seconds = period_to_step(period) * 100
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    remainder = rem(seconds, 60)

    cond do
      hours > 0 and minutes > 0 -> "#{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h"
      minutes > 0 and remainder > 0 -> "#{minutes}m #{remainder}s"
      minutes > 0 -> "#{minutes}m"
      true -> "#{seconds}s"
    end
  end

  defp ntile_to_operation("sum"), do: :sum
  defp ntile_to_operation("max"), do: :max
  defp ntile_to_operation("p99"), do: {:pct, 0.99}
  defp ntile_to_operation("p95"), do: {:pct, 0.95}
  defp ntile_to_operation("p75"), do: {:pct, 0.75}
  defp ntile_to_operation("p50"), do: {:pct, 0.50}

  defp period_to_step("1s"), do: 1
  defp period_to_step("5s"), do: 5
  defp period_to_step("10s"), do: 10
  defp period_to_step("30s"), do: 30
  defp period_to_step("1m"), do: 60
  defp period_to_step("2m"), do: 120

  @filterable_params ~w(nodes queues workers)a

  defp params_to_filters(params) do
    for {key, vals} <- params, key in @filterable_params do
      case key do
        :nodes -> {:node, vals}
        :queues -> {:queue, vals}
        :workers -> {:worker, vals}
      end
    end
  end

  defp params_to_filters_list(params) do
    params
    |> Map.take(@filterable_params)
    |> Enum.sort()
    |> Enum.map_join(", ", fn {key, vals} -> "#{key}: #{Enum.join(List.wrap(vals), ", ")}" end)
  end

  # JS Commands

  defp toggle_chart(target) do
    %JS{}
    |> JS.toggle(in: "fade-in-scale", out: "fade-out-scale", to: "#chart-body")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#chart-toggle")
    |> JS.add_class("rotate-90", to: "#chart-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#chart-chevron.rotate-90")
    |> JS.push("toggle-visible", target: target)
  end
end
