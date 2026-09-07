defmodule Oban.Web.Jobs.ChartComponent do
  use Oban.Web, :live_component

  alias Oban.Met
  alias Oban.Web.Colors
  alias Oban.Web.Components.Core
  alias Oban.Web.Timing

  # Keep failure states at the baseline where spikes are easiest to spot, so the bulk of completed
  # jobs stack on top.
  @stack_order ~w(discarded retryable cancelled completed executing available suspended scheduled)

  @storable ~w(ntile period series visible)a

  # A filter with two or more values is the only signal that the operator wants to compare across
  # that dimension. A single value narrows the data while the state stack keeps explaining it.
  @group_params [worker: :workers, node: :nodes, queue: :queues]

  @count_series ~w(exec_count full_count)
  @time_series ~w(exec_time wait_time)

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok,
     assign(socket,
       group: "state",
       hidden: MapSet.new(),
       max_cols: 100,
       max_data: 7
     )}
  end

  # The parent only re-renders this component when an assign changes, so the refresh timestamp
  # is what brings each tick here. A render caused by anything else, such as mirrored settings,
  # carries the same timestamp and filters and skips the query.
  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    default_series = hd(series())

    fresh? =
      assigns.os_time != socket.assigns[:os_time] or assigns.params != socket.assigns[:params]

    socket =
      socket
      |> assign(conf: assigns.conf, os_time: assigns.os_time, params: assigns.params)
      |> assign_new(:ntile, fn -> init_lazy(:ntile, assigns, ntile_for_series(default_series)) end)
      |> assign_new(:period, fn -> init_lazy(:period, assigns, hd(periods())) end)
      |> assign_new(:series, fn -> init_lazy(:series, assigns, default_series) end)
      |> assign_new(:visible, fn -> init_lazy(:visible, assigns, true) end)
      |> assign_new(:datasets, fn -> [] end)
      |> assign_new(:truncated, fn -> 0 end)

    socket =
      if fresh? and socket.assigns.visible do
        socket = assign_datasets(socket)

        push_event(socket, "chart-change", chart_payload(socket.assigns, false))
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
    assigns = assign(assigns, subtitle: subtitle(assigns), label: chart_label(assigns))

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
            ({@subtitle})
          </span>

          <span
            :if={@params |> params_to_filters() |> Enum.any?()}
            id="chart-filtered-alert"
            class="w-3 h-3 ml-1 bg-violet-500 rounded-full"
            data-title={"Filtered by #{params_to_filters_list(@params)}"}
            phx-hook="Tippy"
          ></span>
        </div>

        <div id="chart-c" class="flex items-center space-x-2">
          <div
            id="chart-series"
            role="radiogroup"
            aria-label="Metric series"
            class="hidden md:flex items-center gap-0.5 p-0.5 rounded-md bg-gray-100 dark:bg-gray-800"
            phx-hook="Segmented"
          >
            <.series_option
              :for={value <- series()}
              disabled={not @visible}
              myself={@myself}
              selected={@series}
              value={value}
            />
          </div>

          <Core.dropdown_menu
            id="chart-options"
            aria_label="Chart options"
            disabled={not @visible}
            menu_class="w-36 overflow-hidden"
            title="Chart options"
            toggle_class="hidden md:flex h-9 w-9 items-center justify-center text-gray-500 dark:text-gray-400
            enabled:hover:text-gray-700 dark:enabled:hover:text-gray-200
            enabled:hover:bg-black/5 dark:enabled:hover:bg-white/5
            disabled:text-gray-400 disabled:dark:text-gray-500"
          >
            <:toggle>
              <Icons.icon name="icon-adjustments-horizontal" />
            </:toggle>

            <.menu_heading text="Period" />

            <.chart_option
              :for={value <- periods()}
              myself={@myself}
              name="period"
              selected={@period}
              value={value}
            />

            <%!-- Counts are sums, so a percentile only means something for the time series. --%>
            <.menu_heading :if={time_series?(@series)} text="Percentile" divided={true} />

            <.chart_option
              :for={value <- ntiles()}
              :if={time_series?(@series)}
              myself={@myself}
              name="ntile"
              selected={@ntile}
              value={value}
            />
          </Core.dropdown_menu>
        </div>
      </div>

      <div id="chart-body" class={unless(@visible, do: "hidden")}>
        <div
          id="chart"
          class="w-full relative cursor-crosshair pl-5 pr-3 h-45"
          role="img"
          aria-label={@label}
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
            :if={@truncated > 0 and time_series?(@series)}
            class="text-gray-400 dark:text-gray-500"
          >
            +{@truncated} more
          </span>
        </div>
      </div>
    </div>
    """
  end

  attr :disabled, :boolean, required: true
  attr :myself, :any, required: true
  attr :selected, :string, required: true
  attr :value, :string, required: true

  defp series_option(assigns) do
    assigns = assign(assigns, checked: assigns.value == assigns.selected)

    ~H"""
    <button
      id={"select-series-#{@value}"}
      type="button"
      role="radio"
      aria-checked={to_string(@checked)}
      tabindex={if @checked, do: "0", else: "-1"}
      disabled={@disabled}
      class="h-7 px-2.5 rounded text-xs font-medium cursor-pointer text-gray-500 dark:text-gray-400
      enabled:hover:text-gray-700 dark:enabled:hover:text-gray-200
      aria-checked:bg-white dark:aria-checked:bg-gray-700 aria-checked:shadow-sm
      aria-checked:text-blue-500 dark:aria-checked:text-blue-400
      disabled:cursor-not-allowed disabled:text-gray-400 dark:disabled:text-gray-500
      focus:outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
      data-title={metric_label(@value)}
      phx-click="select-series"
      phx-hook="Tippy"
      phx-target={@myself}
      phx-value-choice={@value}
    >
      {series_label(@value)}
    </button>
    """
  end

  attr :text, :string, required: true
  attr :divided, :boolean, default: false

  defp menu_heading(assigns) do
    ~H"""
    <li
      role="none"
      class={[
        "px-2 pt-1 pb-0.5 text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400",
        @divided && "mt-1 pt-2 border-t border-gray-200 dark:border-gray-700"
      ]}
    >
      {@text}
    </li>
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
        |> Core.close_menu("chart-options")
        |> JS.focus(to: "#chart-options-menu-toggle")
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

  defp assign_datasets(socket) do
    %{group: previous, hidden: hidden, params: params, series: series} = socket.assigns

    group = derive_group(params, series)
    hidden = if group == previous, do: hidden, else: MapSet.new()

    socket = assign(socket, group: group, hidden: hidden)
    {datasets, truncated} = datasets(socket.assigns)

    assign(socket, datasets: datasets, truncated: truncated)
  end

  # Full counts are gauges labelled by state and queue alone, so nodes and workers can't group them.
  defp derive_group(params, "full_count") do
    find_group(params, Keyword.take(@group_params, [:queue]))
  end

  defp derive_group(params, _series), do: find_group(params, @group_params)

  defp find_group(params, candidates) do
    Enum.find_value(candidates, "state", fn {group, key} ->
      if match?([_, _ | _], List.wrap(Map.get(params, key))), do: to_string(group)
    end)
  end

  # Slices are labelled from the same snapped time the query runs at, so a payload triggered by
  # a patch lines up with those from refreshes instead of trailing them by a step.
  defp datasets(assigns) do
    %{group: group, params: params} = assigns

    step = period_to_step(assigns.period)
    cols = assigns.max_cols
    sy_time = Timing.snap(System.system_time(:second), step)
    state = Map.get(params, :state)

    opts = [
      by: step,
      filters: params_to_filters(params) ++ state_filter(group, state),
      group: group,
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

    colors = group_colors(grouped, group)

    datasets =
      for {label, slices} <- grouped do
        {hex, dot_class} = Map.fetch!(colors, label)

        %{
          label: label,
          hex: hex,
          dot_class: dot_class,
          ghost: false,
          data: interpolate(slices, cols, step, sy_time)
        }
      end

    datasets =
      datasets
      |> order_datasets(group)
      |> isolate(group, state)

    {datasets, truncated}
  end

  # With the state stack the selected state is emphasised in place; with any other grouping it
  # narrows the query instead, which is how "discarded by queue" becomes the chart.
  defp state_filter("state", _state), do: []
  defp state_filter(_group, nil), do: []
  defp state_filter(_group, state), do: [state: [state]]

  # Isolation only applies when the selected state has a series. Choosing `available` while
  # looking at execution counts should not gray out the whole chart.
  defp isolate(datasets, "state", state) when is_binary(state) do
    if Enum.any?(datasets, &(&1.label == state)) do
      datasets
      |> Enum.map(&Map.put(&1, :ghost, &1.label != state))
      |> Enum.sort_by(& &1.ghost)
    else
      datasets
    end
  end

  defp isolate(datasets, _group, _state), do: datasets

  # Every state fits, so only other groupings are capped. Counts fold the remainder into an
  # "other" series so the stack height stays truthful; percentiles can't be combined, so those
  # series are dropped and the legend says how many.
  defp limit_groups(grouped, %{group: "state"}), do: {grouped, 0}

  defp limit_groups(grouped, assigns) do
    {kept, rest} = Enum.split(grouped, assigns.max_data)

    cond do
      rest == [] ->
        {kept, 0}

      assigns.series in @count_series ->
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

      %{x: x, y: y}
    end
  end

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("select-ntile", %{"choice" => ntile}, socket) do
    {:noreply, push_change(socket, ntile: ntile)}
  end

  def handle_event("select-period", %{"choice" => period}, socket) do
    {:noreply, push_change(socket, period: period)}
  end

  def handle_event("select-series", %{"choice" => series}, socket) do
    ntile =
      cond do
        series == "full_count" -> "max"
        series in @time_series -> "p95"
        true -> "sum"
      end

    {:noreply, push_change(socket, hidden: MapSet.new(), ntile: ntile, series: series)}
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
      |> assign_datasets()

    push_event(socket, "chart-change", chart_payload(socket.assigns, true))
  end

  # The server clock is included so the browser can place the window's right edge on server time
  # rather than its own clock, which may sit seconds away from the slices it draws. The key names
  # what the points measure, so the browser can keep slices it has already seen while the key
  # holds and drop them the moment the series, grouping, percentile, period, or filters change.
  # Settings ride along only when a selection changed, which is when the browser stores them.
  defp chart_payload(assigns, settings?) do
    payload = %{
      group: assigns.group,
      hidden: MapSet.to_list(assigns.hidden),
      key: data_key(assigns),
      now: System.system_time(:millisecond),
      points: Enum.map(assigns.datasets, &Map.take(&1, [:label, :hex, :ghost, :data])),
      series: assigns.series,
      step: period_to_step(assigns.period)
    }

    if settings? do
      Map.put(payload, :settings, Map.take(assigns, [:ntile, :period, :series, :visible]))
    else
      payload
    end
  end

  defp data_key(assigns) do
    %{group: group, ntile: ntile, params: params, period: period, series: series} = assigns

    filters = params_to_filters(params) ++ state_filter(group, Map.get(params, :state))

    :erlang.phash2({series, group, ntile, period, Enum.sort(filters)})
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

  defp ntiles, do: ~w(max p99 p95 p75 p50)
  defp periods, do: ~w(1s 5s 10s 30s 1m 2m)
  defp series, do: ~w(exec_count full_count exec_time wait_time)

  defp time_series?(series), do: series in @time_series

  defp ntile_for_series(series) when series in @time_series, do: "p95"
  defp ntile_for_series(_series), do: "sum"

  defp metric_label("exec_count"), do: "Executed Count"
  defp metric_label("full_count"), do: "Full Count"
  defp metric_label("exec_time"), do: "Execution Time"
  defp metric_label("wait_time"), do: "Queue Time"

  defp metric_noun("exec_count"), do: "executions"
  defp metric_noun("full_count"), do: "jobs"
  defp metric_noun("exec_time"), do: "execution times"
  defp metric_noun("wait_time"), do: "queue times"

  defp series_label("exec_count"), do: "exec"
  defp series_label("full_count"), do: "full"
  defp series_label("exec_time"), do: "time"
  defp series_label("wait_time"), do: "wait"

  defp subtitle(%{group: group, ntile: ntile, params: params, period: period, series: series}) do
    base =
      if series in @time_series,
        do: "#{ntile} · #{period} by #{String.capitalize(group)}",
        else: "#{period} by #{String.capitalize(group)}"

    case {group, Map.get(params, :state)} do
      {"state", _state} -> base
      {_group, nil} -> base
      {_group, state} -> "#{base}, #{state}"
    end
  end

  defp chart_label(%{datasets: [], period: period, series: series}) do
    empty_label(series, period)
  end

  defp chart_label(%{datasets: datasets, params: params, series: series} = assigns) do
    label = "#{metric_label(series)}, #{subtitle(assigns)}"

    if Enum.any?(datasets, & &1.ghost),
      do: "#{label}, #{Map.get(params, :state)} isolated",
      else: label
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
