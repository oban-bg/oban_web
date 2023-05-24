defmodule Oban.Web.Live.Chart do
  use Oban.Web, :live_component

  alias Oban.Met
  alias Oban.Web.Components.Core

  @default_color "fill-zinc-400"
  @default_guides_max 20

  @color_palette ~w(
    fill-cyan-400
    fill-violet-400
    fill-yellow-400
    fill-green-400
    fill-orange-400
    fill-teal-400
    fill-pink-300
  )

  @state_palette %{
    "available" => "fill-teal-400",
    "cancelled" => "fill-violet-400",
    "completed" => "fill-cyan-400",
    "discarded" => "fill-orange-400",
    "executing" => "fill-pink-300",
    "retryable" => "fill-yellow-400",
    "scheduled" => "fill-green-400"
  }

  @period_to_step %{
    "1s" => 1,
    "5s" => 5,
    "10s" => 10,
    "30s" => 30,
    "1m" => 60,
    "2m" => 120
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, group: "state", period: "1s", series: :exec_count)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    rows = 108
    step = Map.fetch!(@period_to_step, socket.assigns.period)
    back = rows * step
    time = snap_timestamp(assigns.os_time, step)

    timeslice =
      Met.timeslice(
        assigns.conf.name,
        socket.assigns.series,
        by: step,
        group: socket.assigns.group,
        lookback: back,
        since: snap_timestamp(System.system_time(:second), step)
      )

    {slices, max} =
      Enum.reduce(0..(rows - 1), {[], 0}, fn idx, {acc, oldmax} ->
        tstamp = time - idx * step

        slices =
          timeslice
          |> Enum.filter(&(elem(&1, 0) == idx))
          |> then(&:lists.ukeysort(3, &1))

        total = Enum.reduce(slices, 0, &(elem(&1, 1) + &2))

        {[{idx, tstamp, total, slices} | acc], max(total, oldmax)}
      end)

    palette =
      if socket.assigns.group == "state" do
        @state_palette
      else
        timeslice
        |> Enum.map(&elem(&1, 2))
        |> :lists.usort()
        |> Enum.zip(@color_palette)
        |> Map.new()
      end

    socket =
      socket
      |> assign(closed?: false, height: 180, width: 1100, guides: 5)
      |> assign(max: max, palette: palette, slices: slices, step: step)

    {:ok, socket}
  end

  defp snap_timestamp(unix, step) when rem(unix, step) == 0, do: unix
  defp snap_timestamp(unix, step), do: snap_timestamp(unix + 1, step)

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
            options={~w(exec_count full_count exec_time wait_time)}
            target={@myself}
          >
            <Icons.chart_bar_square />
          </Core.dropdown_button>

          <Core.dropdown_button
            name="period"
            title="Change slice period"
            selected={@period}
            options={~w(1s 5s 10s 30s 1m 2m)}
            target={@myself}
          >
            <Icons.clock />
          </Core.dropdown_button>

          <Core.dropdown_button
            name="group"
            title="Change metric grouping"
            selected={@group}
            options={~w(state queue node worker)}
            target={@myself}
          >
            <Icons.rectangle_group />
          </Core.dropdown_button>

          <Core.dropdown_button
            name="ntile"
            title="Change percentile"
            selected="p95"
            options={~w(p99 p95 p75 p50)}
          >
            <Icons.receipt_percent />
          </Core.dropdown_button>
        </div>
      </div>

      <svg
        id="chart"
        class="w-full overflow-visible relative z-10"
        height={@height + 35}
        phx-hook="Chart"
      >
        <g id="chart-y" transform="translate(42, 0)">
          <%= for {label, index} <- Enum.with_index(guide_values(@max, @guides)) do %>
            <.guide
              height={@height}
              index={index}
              label={label}
              total={@guides - 1}
              width={@width - 20}
            />
          <% end %>
        </g>

        <g id="chart-x" transform={"translate(42, #{@height + 25})"}>
          <%= for {index, tstamp, _total, _values} <- @slices, tick_at_time?(tstamp, @step) do %>
            <.tick index={index} tstamp={tstamp} width={@width - 20} />
          <% end %>
        </g>

        <g id="chart-d" transform="translate(24, 10)">
          <%= for {index, tstamp, total, values} <- @slices do %>
            <.col
              index={index}
              max={@max}
              palette={@palette}
              total={total}
              total_height={@height}
              total_width={@width}
              tstamp={tstamp}
              values={values}
            />
          <% end %>
        </g>

        <g id="chart-tooltip-wrapper" phx-update="ignore"></g>

        <defs>
          <g rel="chart-tooltip">
            <polygon
              rel="arrow"
              class="fill-gray-900"
              points="0,8 8,0 16,8"
              transform="translate(52, 0)"
            />
            <rect rel="rect" class="fill-gray-900" height="112" width="120" rx="6" y="8" />
            <text rel="date" class="fill-gray-100 text-xs font-semibold tabular" x="8" y="26">0</text>
            <g rel="labs"></g>
          </g>

          <g rel="chart-tooltip-label">
            <circle cy="-4" r="4" />
            <text class="fill-gray-300 text-xs tabular capitalize" x="10">0</text>
          </g>
        </defs>
      </svg>
    </div>
    """
  end

  defp tick_at_time?(unix, step) when step < 10, do: Integer.mod(unix, 10) == 0
  defp tick_at_time?(unix, step) when step < 60, do: Integer.mod(unix, 100) == 0
  defp tick_at_time?(unix, _step), do: Integer.mod(unix, 1000) == 0

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("select-group", %{"choice" => group}, socket) do
    Process.send_after(self(), :refresh, 50)

    {:noreply, assign(socket, group: group)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("select-period", %{"choice" => period}, socket) do
    Process.send_after(self(), :refresh, 50)

    {:noreply, assign(socket, period: period)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("select-series", %{"choice" => series}, socket) do
    Process.send_after(self(), :refresh, 50)

    {:noreply, assign(socket, series: String.to_existing_atom(series))}
  end

  # Guides

  @doc false
  def guide_values(max, total) when max > 0 and total > 1 do
    top = ceil(max * 1.10 / 10) * 10
    step = div(top, total - 1)

    for num <- 0..top//step, do: integer_to_estimate(num)
  end

  def guide_values(0, total), do: guide_values(@default_guides_max, total)

  # JS Commands

  defp toggle_chart(js \\ %JS{}) do
    js
    |> JS.toggle(in: "fade-in-scale", out: "fade-out-scale", to: "#chart")
    |> JS.add_class("rotate-90", to: "#chart-toggle svg:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#chart-toggle svg.rotate-90")
  end

  # Label Helpers

  defp metric_label(:exec_count), do: "Executed"
  defp metric_label(:full_count), do: "Total"
  defp metric_label(:exec_time), do: "Execution Time"
  defp metric_label(:wait_time), do: "Queue Time"

  # Components

  defp guide(assigns) do
    ~H"""
    <g transform={"translate(0, #{@height + 10 - @index * div(@height, @total)})"} text-anchor="end">
      <line class="stroke-gray-300 dark:text-gray-700" stroke-dasharray="4,4" x2={@width} />
      <text class="fill-gray-600 text-xs tabular" x="-4" dy="0.32em">
        <%= @label %>
      </text>
    </g>
    """
  end

  defp tick(assigns) do
    assigns =
      assign(
        assigns,
        datetime: DateTime.from_unix!(assigns.tstamp),
        x: assigns.width - 10 - assigns.index * 10
      )

    ~H"""
    <g transform={"translate(#{@x}, 0)"}>
      <line class="stroke-gray-300 dark:text-gray-700" y1={-15} y2={-10} />

      <%= if @datetime.second == 0 and @x in 20..@width - 20 do %>
        <text class="fill-gray-600 text-xs tabular" text-anchor="middle" y="2">
          <%= Calendar.strftime(@datetime, "%H:%M") %>
        </text>
      <% end %>
    </g>
    """
  end

  defp col(assigns) do
    inner_height = trunc(assigns.total / assigns.max * assigns.total_height * 0.9)
    offset = assigns.total_width - 10 - assigns.index * 10

    assigns = assign(assigns, inner_height: inner_height, offset: offset)

    ~H"""
    <g
      class="group"
      id={"col-#{@tstamp}"}
      transform={"translate(#{@offset}, 0)"}
      data-offset={@offset}
      data-tstamp={@tstamp}
    >
      <rect class="fill-transparent group-hover:fill-gray-200" width="9" height={@total_height} />

      <%= for {value, label, y, height, color} <- build_stack(@values, @total, @inner_height, @total_height, @palette) do %>
        <rect class={color} width="9" y={y} height={height} data-label={label} data-value={value} />
      <% end %>
    </g>
    """
  end

  defp build_stack(_values, 0, _inner, _total, _palette), do: []

  defp build_stack(values, total_count, inner_height, total_height, palette) do
    {stack, _y, _idx} =
      Enum.reduce(values, {[], 0, 0}, fn {_chk, value, label}, {acc, prev_y, idx} ->
        case value / total_count * inner_height do
          0.0 ->
            {acc, prev_y, idx + 1}

          height ->
            estimate = integer_to_estimate(value)
            y = total_height - height - prev_y
            color = Map.get(palette, label, @default_color)

            {[{estimate, label, y, height, color} | acc], prev_y + height, idx + 1}
        end
      end)

    stack
  end
end
