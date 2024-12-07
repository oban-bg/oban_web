defmodule Oban.Web.Jobs.ChartComponent do
  use Oban.Web, :live_component

  alias Oban.Met
  alias Oban.Web.Components.Core
  alias Oban.Web.Timing

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, last_os_time: 0, max_cols: 100, max_data: 7)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(conf: assigns.conf, params: assigns.params)
      |> assign_new(:group, fn -> init_lazy(:group, assigns, hd(groups())) end)
      |> assign_new(:ntile, fn -> init_lazy(:ntile, assigns, "sum") end)
      |> assign_new(:period, fn -> init_lazy(:period, assigns, hd(periods())) end)
      |> assign_new(:series, fn -> init_lazy(:series, assigns, hd(series())) end)
      |> assign_new(:visible, fn -> init_lazy(:visible, assigns, true) end)

    socket =
      if socket.assigns.visible do
        step = period_to_step(socket.assigns.period)
        os_time = Timing.snap(assigns.os_time, step)
        points = points(os_time, socket.assigns)
        update = %{group: socket.assigns.group, points: points, series: socket.assigns.series}

        socket
        |> assign(last_os_time: os_time)
        |> push_event("chart-change", update)
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
    <div class="bg-white dark:bg-gray-900 rounded-md shadow-md w-full mb-3">
      <div class="flex items-center justify-between p-3">
        <div id="chart-h" class="flex items-center text-gray-900 dark:text-gray-200">
          <button
            id="chart-toggle"
            data-title="Toggle charts"
            phx-click={toggle_chart(@myself)}
            phx-hook="Tippy"
          >
            <Icons.chevron_right class={[
              "w-5 h-5 mr-2 transition-transform",
              if(@visible, do: "rotate-90")
            ]} />
          </button>

          <h3 class="text-base font-semibold">
            {metric_label(@series)}
          </h3>

          <span class="text-gray-600 dark:text-gray-400 font-light ml-1">
            ({@period} by {String.capitalize(@group)})
          </span>

          <span
            :if={@params |> params_to_filters() |> Enum.any?()}
            id="chart-filtered-alert"
            class="w-3 h-3 ml-1 bg-violet-300 rounded-full"
            data-title={"Filtered by #{params_to_filters_list(@params)}"}
            phx-hook="Tippy"
          >
          </span>
        </div>

        <div id="chart-c" class="flex space-x-2">
          <Core.dropdown_button
            disabled={not @visible}
            name="series"
            options={series()}
            selected={@series}
            target={@myself}
            title="Change metric series"
          >
            <Icons.chart_bar_square />
          </Core.dropdown_button>

          <Core.dropdown_button
            disabled={not @visible}
            name="period"
            options={periods()}
            selected={@period}
            target={@myself}
            title="Change slice period"
          >
            <Icons.clock />
          </Core.dropdown_button>

          <Core.dropdown_button
            disabled={not @visible}
            name="group"
            options={groups_for_series(@series)}
            selected={@group}
            target={@myself}
            title="Change metric grouping"
          >
            <Icons.rectangle_group />
          </Core.dropdown_button>

          <Core.dropdown_button
            disabled={not @visible or @series in ~w(exec_count full_count)}
            name="ntile"
            options={ntiles()}
            selected={@ntile}
            target={@myself}
            title="Change percentile"
          >
            <Icons.percent_square />
          </Core.dropdown_button>
        </div>
      </div>

      <div
        id="chart"
        class={["w-full relative cursor-crosshair pl-5 pr-3", unless(@visible, do: "hidden")]}
        style="height: 200px;"
      >
        <canvas id="chart-canvas" phx-update="ignore" phx-hook="Charter"></canvas>
      </div>
    </div>
    """
  end

  # Data

  defp points(os_time, assigns) do
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

    assigns.conf.name
    |> Met.timeslice(String.to_existing_atom(assigns.series), opts)
    |> Enum.group_by(&elem(&1, 2), &Tuple.delete_at(&1, 2))
    |> top_n(assigns.max_data)
    |> Map.new(fn {label, slices} -> {label, interpolate(slices, cols, step, os_time)} end)
  end

  defp top_n(points, limit) do
    points
    |> Enum.sort_by(fn {_key, data} -> Enum.reduce(data, 0, &(elem(&1, 1) + &2)) end, :desc)
    |> Enum.take(limit)
  end

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
    {:noreply, push_change(socket, group: group)}
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

    {:noreply, push_change(socket, assigns)}
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
    os_time = socket.assigns.last_os_time
    socket = assign(socket, change)
    points = points(os_time, Map.put(socket.assigns, :last_os_time, 0))

    update = %{
      group: socket.assigns.group,
      ntile: socket.assigns.ntile,
      period: socket.assigns.period,
      points: points,
      series: socket.assigns.series,
      visible: socket.assigns.visible
    }

    push_event(socket, "chart-change", update)
  end

  # Lookups

  def groups, do: ~w(state queue node worker)
  def ntiles, do: ~w(max p99 p95 p75 p50)
  def periods, do: ~w(1s 5s 10s 30s 1m 2m)
  def series, do: ~w(exec_count full_count exec_time wait_time)

  defp groups_for_series("full_count"), do: ~w(state queue)
  defp groups_for_series(_series), do: groups()

  defp metric_label("exec_count"), do: "Executed Count"
  defp metric_label("full_count"), do: "Full Count"
  defp metric_label("exec_time"), do: "Execution Time"
  defp metric_label("wait_time"), do: "Queue Time"

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
    |> Map.keys()
    |> Enum.sort()
    |> Enum.join(", ")
  end

  # JS Commands

  defp toggle_chart(target) do
    %JS{}
    |> JS.toggle(in: "fade-in-scale", out: "fade-out-scale", to: "#chart")
    |> JS.add_class("rotate-90", to: "#chart-toggle svg:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#chart-toggle svg.rotate-90")
    |> JS.push("toggle-visible", target: target)
  end
end
