defmodule Oban.Web.Live.Chart do
  use Oban.Web, :live_component

  alias Oban.Met
  alias Oban.Web.Components.Core
  alias Oban.Web.Timing

  @impl Phoenix.LiveComponent
  def mount(socket) do
    socket =
      socket
      |> assign_new(:group, fn -> List.first(groups()) end)
      |> assign_new(:ntile, fn -> List.first(ntiles()) end)
      |> assign_new(:period, fn -> List.first(periods()) end)
      |> assign_new(:series, fn -> List.first(series()) end)
      |> assign(init: true)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    %{group: group, ntile: ntile, period: period, series: series} = socket.assigns

    step = period_to_step(period)
    time = Timing.snap(System.system_time(:second), step)
    cols = if socket.assigns.init, do: 100, else: 1

    labels = Met.labels(assigns.conf.name, group, since: time)

    opts = [
      by: step,
      filters: params_to_filters(assigns.params),
      group: group,
      lookback: cols * step,
      ntile: ntile_to_float(ntile),
      since: time
    ]

    points =
      assigns.conf.name
      |> Met.timeslice(series, opts)
      |> Enum.group_by(&elem(&1, 2), &Tuple.delete_at(&1, 2))
      |> Map.new(fn {label, slices} -> {label, interpolate(slices, cols)} end)

    update = %{cols: cols, labels: labels, points: points, series: series, step: step, time: time}

    socket =
      socket
      |> assign(conf: assigns.conf, init: false)
      |> push_event("chart-update", update)

    {:ok, socket}
  end

  defp interpolate(slices, steps) do
    lookup = Map.new(slices)

    for index <- 0..(steps - 1), do: Map.get(lookup, index, 0)
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-900 rounded-md shadow-md w-full mb-3">
      <div class="flex items-center justify-between p-3">
        <h3 class="flex items-center text-gray-900 dark:text-gray-200 text-base font-semibold">
          <button
            id="chart-toggle"
            data-title="Toggle charts"
            phx-click={toggle_chart()}
            phx-hook="Tippy"
          >
            <Icons.chevron_right class="w-5 h-5 mr-2 transition-transform rotate-90" />
          </button>
          <%= metric_label(@series) %>
          <span class="text-gray-600 dark:text-gray-400 font-light ml-1">
            (<%= @period %> by <%= String.capitalize(@group) %>)
          </span>
        </h3>

        <div id="chart-c" class="flex space-x-2">
          <Core.dropdown_button
            name="series"
            title="Change metric series"
            selected={@series}
            options={series()}
            target={@myself}
          >
            <Icons.chart_bar_square />
          </Core.dropdown_button>

          <Core.dropdown_button
            name="period"
            title="Change slice period"
            selected={@period}
            options={periods()}
            target={@myself}
          >
            <Icons.clock />
          </Core.dropdown_button>

          <Core.dropdown_button
            name="group"
            title="Change metric grouping"
            selected={@group}
            options={groups_for_series(@series)}
            target={@myself}
          >
            <Icons.rectangle_group />
          </Core.dropdown_button>

          <Core.dropdown_button
            name="ntile"
            disabled={@series in ~w(exec_count full_count)a}
            title="Change percentile"
            selected={@ntile}
            options={ntiles()}
            target={@myself}
          >
            <Icons.percent_square />
          </Core.dropdown_button>
        </div>
      </div>

      <div class="cursor-crosshair pl-5 pr-3" style="height: 200px">
        <canvas id="chart-canvas" phx-update="ignore" phx-hook="Chart"></canvas>
      </div>
    </div>
    """
  end

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("select-group", %{"choice" => group}, socket) do
    {:noreply, assign(socket, init: true, group: group)}
  end

  def handle_event("select-ntile", %{"choice" => ntile}, socket) do
    {:noreply, assign(socket, init: true, ntile: ntile)}
  end

  def handle_event("select-period", %{"choice" => period}, socket) do
    {:noreply, assign(socket, init: true, period: period)}
  end

  def handle_event("select-series", %{"choice" => series}, socket) do
    assigns =
      if series == "full_count" and socket.assigns.group in ~w(node worker) do
        [init: true, group: "state", series: :full_count]
      else
        [init: true, series: String.to_existing_atom(series)]
      end

    {:noreply, assign(socket, assigns)}
  end

  # Lookups

  def groups, do: ~w(state queue node worker)
  def ntiles, do: ~w(max p99 p95 p75 p50)
  def periods, do: ~w(1s 5s 10s 30s 1m 2m)
  def series, do: ~w(exec_count full_count exec_time wait_time)a
  def states, do: ~w(completed cancelled retryable scheduled discarded available executing)

  defp groups_for_series(:full_count), do: ~w(state queue)
  defp groups_for_series(_series), do: groups()

  defp metric_label(:exec_count), do: "Executed"
  defp metric_label(:full_count), do: "Total"
  defp metric_label(:exec_time), do: "Execution Time"
  defp metric_label(:wait_time), do: "Queue Time"

  defp ntile_to_float("max"), do: 1.0
  defp ntile_to_float("p99"), do: 0.99
  defp ntile_to_float("p95"), do: 0.95
  defp ntile_to_float("p75"), do: 0.75
  defp ntile_to_float("p50"), do: 0.50

  defp period_to_step("1s"), do: 1
  defp period_to_step("5s"), do: 5
  defp period_to_step("10s"), do: 10
  defp period_to_step("30s"), do: 30
  defp period_to_step("1m"), do: 60
  defp period_to_step("2m"), do: 120

  defp params_to_filters(params) do
    for {key, vals} <- params, key in ~w(nodes queues)a do
      case key do
        :nodes -> {:node, vals}
        :queues -> {:queue, vals}
      end
    end
  end

  # JS Commands

  defp toggle_chart(js \\ %JS{}) do
    js
    |> JS.toggle(in: "fade-in-scale", out: "fade-out-scale", to: "#chart")
    |> JS.add_class("rotate-90", to: "#chart-toggle svg:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#chart-toggle svg.rotate-90")
  end
end
