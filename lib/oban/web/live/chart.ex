defmodule Oban.Web.Live.Chart do
  use Oban.Web, :live_component

  alias Oban.Met
  alias Oban.Web.Components.Core

  # TODO: Pull this from options
  @default_guides_max 20

  @default_opts %{
    height_clamp: 0.9,
    guides: 5,
    height: 180,
    columns: 108,
    width: 1100
  }

  # Full color classes listed for Tailwind

  @fill_palette ~w(
    fill-cyan-400
    fill-violet-400
    fill-yellow-400
    fill-green-400
    fill-orange-400
    fill-teal-400
    fill-pink-300
  )

  @stroke_palette ~w(
    stroke-cyan-400
    stroke-violet-400
    stroke-yellow-400
    stroke-green-400
    stroke-orange-400
    stroke-teal-400
    stroke-pink-300
  )

  @stack_series ~w(exec_count full_count)a
  @lines_series ~w(exec_time wait_time)a

  @impl Phoenix.LiveComponent
  def mount(socket) do
    socket =
      socket
      |> assign_new(:group, fn -> List.first(groups()) end)
      |> assign_new(:ntile, fn -> List.first(ntiles()) end)
      |> assign_new(:period, fn -> List.first(periods()) end)
      |> assign_new(:series, fn -> List.first(series()) end)
      |> assign(opts: @default_opts)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    %{group: group, ntile: ntile, period: period} = socket.assigns
    %{opts: opts, series: series} = socket.assigns

    step = period_to_step(period)
    os_time = snap_timestamp(assigns.os_time, step)

    slices =
      Met.timeslice(assigns.conf.name, series,
        by: step,
        filters: params_to_filters(assigns.params),
        group: group,
        lookback: opts.columns * step,
        ntile: ntile_to_float(ntile),
        since: snap_timestamp(System.system_time(:second), step)
      )

    max = build_max(slices, series)

    opts =
      Map.merge(opts, %{
        default_color: "zinc-400",
        palette: build_palette(series, group, slices)
      })

    {:ok, assign(socket, max: max, opts: opts, step: step, time: os_time, slices: slices)}
  end

  defp snap_timestamp(unix, step) when rem(unix, step) == 0, do: unix
  defp snap_timestamp(unix, step), do: snap_timestamp(unix + 1, step)

  defp params_to_filters(params) do
    for {key, vals} <- params, key in ~w(nodes queues)a do
      case key do
        :nodes -> {:node, vals}
        :queues -> {:queue, vals}
      end
    end
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

      <svg
        id="chart"
        class="w-full overflow-visible relative z-10 cursor-crosshair"
        height={@opts.height + 35}
        phx-hook="Chart"
      >
        <g id="chart-y" transform="translate(42, 0)">
          <.guide
            :for={{label, index} <- build_guides(@max, @series, @opts)}
            height={@opts.height}
            index={index}
            label={label}
            total={@opts.guides - 1}
            width={@opts.width - 20}
          />
        </g>

        <g id="chart-x" transform={"translate(42, #{@opts.height + 25})"}>
          <.tick
            :for={{index, tstamp} <- build_ticks(@time, @step, @opts)}
            index={index}
            tstamp={tstamp}
            width={@opts.width - 20}
          />
        </g>

        <g id="chart-d" transform="translate(24, 10)">
          <%= if stack_mode?(@series) do %>
            <.stack
              :for={{index, tstamp, stacks} <- build_stacks(@slices, @step, @time, @max, @opts)}
              index={index}
              opts={@opts}
              stacks={stacks}
              tstamp={tstamp}
            />
          <% end %>

          <%= if lines_mode?(@series) do %>
            <.lines
              :for={{stacks, points} <- [build_lines(@slices, @step, @time, @max, @opts)]}
              opts={@opts}
              points={points}
              stacks={stacks}
            />
          <% end %>
        </g>

        <g id="chart-t" phx-update="ignore"></g>

        <defs>
          <g rel="chart-tooltip">
            <polygon rel="arrw" class="fill-gray-900" points="0,8 8,0 16,8" />
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

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("select-group", %{"choice" => group}, socket) do
    {:noreply, assign_with_refresh(socket, group: group)}
  end

  def handle_event("select-ntile", %{"choice" => ntile}, socket) do
    {:noreply, assign_with_refresh(socket, ntile: ntile)}
  end

  def handle_event("select-period", %{"choice" => period}, socket) do
    {:noreply, assign_with_refresh(socket, period: period)}
  end

  def handle_event("select-series", %{"choice" => series}, socket) do
    assigns =
      if series == "full_count" and socket.assigns.group in ~w(node worker) do
        [series: :full_count, group: "state"]
      else
        [series: String.to_existing_atom(series)]
      end

    {:noreply, assign_with_refresh(socket, assigns)}
  end

  defp assign_with_refresh(socket, assigns) do
    Process.send_after(self(), :refresh, 100)

    assign(socket, assigns)
  end

  # Guides

  @doc false
  def guide_values(max, total) when max > 0 and total > 1 do
    top = ceil(max * 1.10 / 10) * 10
    step = div(top, total - 1)

    for num <- 0..top//step, do: num
  end

  def guide_values(0, total), do: guide_values(@default_guides_max, total)

  # Components

  attr :height, :integer
  attr :index, :integer
  attr :label, :string
  attr :total, :integer
  attr :width, :integer

  defp guide(assigns) do
    ~H"""
    <g transform={"translate(0, #{@height + 10 - @index * div(@height, @total)})"} text-anchor="end">
      <line class="stroke-gray-300 dark:text-gray-700" stroke-dasharray="3,3" x2={@width} />
      <text class="fill-gray-600 text-xs tabular" x="-4" dy="0.32em">
        <%= @label %>
      </text>
    </g>
    """
  end

  attr :index, :integer
  attr :tstamp, :integer
  attr :width, :integer

  defp tick(assigns) do
    assigns =
      assign(
        assigns,
        datetime: DateTime.from_unix!(assigns.tstamp),
        x: offset_for(assigns.index, assigns.width)
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

  attr :index, :integer
  attr :opts, :map
  attr :stacks, :list
  attr :tstamp, :integer

  defp stack(assigns) do
    assigns = assign(assigns, offset: offset_for(assigns.index, assigns.opts.width))

    ~H"""
    <g
      class="group"
      id={"col-#{@tstamp}"}
      transform={"translate(#{@offset}, 0)"}
      data-offset={@offset}
      data-tstamp={@tstamp}
    >
      <rect class="fill-transparent group-hover:fill-gray-200" width="9" height={@opts.height} />

      <%= for {value, label, y, height, color} <- @stacks do %>
        <rect class={color} width="9" y={y} height={height} data-label={label} data-value={value} />
      <% end %>
    </g>
    """
  end

  defp lines(assigns) do
    ~H"""
    <.line_poly :for={{label, points} <- @points} label={label} opts={@opts} points={points} />

    <.line_desc
      :for={{index, stamp, stack} <- @stacks}
      index={index}
      opts={@opts}
      stamp={stamp}
      stack={stack}
    />
    """
  end

  defp line_desc(assigns) do
    assigns = assign(assigns, offset: offset_for(assigns.index, assigns.opts.width))

    ~H"""
    <g
      class="group"
      id={"col-#{@stamp}"}
      transform={"translate(#{@offset}, 0)"}
      data-offset={@offset}
      data-tstamp={@stamp}
    >
      <rect class="fill-transparent" width="10" height={@opts.height} />

      <line class="stroke-transparent group-hover:stroke-gray-200" stroke-width="2" y1={@opts.height} />

      <%= for {value, label} <- @stack do %>
        <desc class={color_for(label, @opts)} data-label={label} data-value={format_μs(value)} />
      <% end %>
    </g>
    """
  end

  defp line_poly(assigns) do
    ~H"""
    <g class="group" id={"poly-#{@label}"}>
      <polyline points={@points} fill="none" class={color_for(@label, @opts)} stroke-width="2" />
    </g>
    """
  end

  # Building

  defp build_max(slices, series) when series in @stack_series do
    slices
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.reduce(1, fn {_, vals}, acc -> max(acc, Enum.sum(vals)) end)
  end

  defp build_max(slices, _series) do
    Enum.reduce(slices, 1, &max(&2, to_μs(elem(&1, 1))))
  end

  defp build_palette(series, group, timeslice) do
    palette = if stack_mode?(series), do: @fill_palette, else: @stroke_palette

    labels =
      if group == "state" do
        states()
      else
        timeslice
        |> Enum.map(&elem(&1, 2))
        |> :lists.usort()
      end

    labels
    |> Enum.zip(palette)
    |> Map.new()
  end

  defp build_guides(max, series, opts) do
    convert =
      if stack_mode?(series) do
        &integer_to_estimate/1
      else
        &format_μs/1
      end

    max
    |> guide_values(opts.guides)
    |> Enum.map(convert)
    |> Enum.with_index()
  end

  def build_ticks(time, step, opts) do
    for index <- 0..(opts.columns - 1),
        stamp = time - index * step,
        tick_at_time?(stamp, step) do
      {index, stamp}
    end
  end

  defp tick_at_time?(unix, step) when step < 10, do: Integer.mod(unix, 10) == 0
  defp tick_at_time?(unix, step) when step < 60, do: Integer.mod(unix, 100) == 0
  defp tick_at_time?(unix, _step), do: Integer.mod(unix, 1000) == 0

  defp build_stacks(slices, step, time, max, opts) do
    Enum.reduce(0..(opts.columns - 1), [], fn index, acc ->
      stamp = time - index * step

      stuff =
        slices
        |> Enum.filter(&(elem(&1, 0) == index))
        |> then(&:lists.ukeysort(3, &1))

      total = Enum.reduce(stuff, 0, &(elem(&1, 1) + &2))
      inner = trunc(total / max * opts.height * opts.height_clamp)

      {stack, _y, _idx} =
        Enum.reduce(stuff, {[], 0, 0}, fn {_chk, value, label}, {acc, prev_y, idx} ->
          case trunc(value / total * inner) do
            0.0 ->
              {acc, prev_y, idx + 1}

            height ->
              color = color_for(label, opts)
              display = integer_to_estimate(value)
              y = opts.height - height - prev_y

              {[{display, label, y, height, color} | acc], prev_y + height, idx + 1}
          end
        end)

      [{index, stamp, stack} | acc]
    end)
  end

  defp build_lines(slices, step, time, max, opts) do
    Enum.reduce(0..(opts.columns - 1), {[], %{}}, fn index, {stacks, points} ->
      stamp = time - index * step

      stuff =
        slices
        |> Enum.filter(&(elem(&1, 0) == index))
        |> Enum.map(fn {_, value, label} -> {to_μs(value), label} end)

      x = offset_for(index, opts.width)

      points =
        Enum.reduce(stuff, points, fn {value, label}, acc ->
          y = opts.height - trunc(value / max * opts.height * opts.height_clamp)
          point = "#{x},#{y} "

          Map.update(acc, label, [point], &[point | &1])
        end)

      {[{index, stamp, stuff} | stacks], points}
    end)
  end

  defp lines_mode?(series), do: series in @lines_series

  defp stack_mode?(series), do: series in @stack_series

  # Formatting

  defp offset_for(index, width), do: width - 10 - index * 10

  defp color_for(label, opts), do: Map.get(opts.palette, label, opts.default_color)

  defp to_μs(value) do
    value
    |> trunc()
    |> System.convert_time_unit(:native, :microsecond)
  end

  defp format_μs(duration) do
    cond do
      duration > 1_000_000 ->
        [duration |> div(1_000_000) |> Integer.to_string(), "s"]

      duration > 1000 ->
        [duration |> div(1000) |> Integer.to_string(), "ms"]

      duration == 0 ->
        "0"

      true ->
        [Integer.to_string(duration), "µs"]
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
