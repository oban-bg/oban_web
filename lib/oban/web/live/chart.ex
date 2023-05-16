defmodule Oban.Web.Live.Chart do
  use Oban.Web, :live_component

  alias Oban.Met
  alias Oban.Web.Components.Core

  @default_guides_max 20

  @empty_states [
    {0, 0, "cancelled"},
    {0, 0, "completed"},
    {0, 0, "discarded"},
    {0, 0, "retryable"},
    {0, 0, "scheduled"}
  ]

  @states_palette %{
    "cancelled" => "fill-violet-400",
    "completed" => "fill-cyan-400",
    "discarded" => "fill-pink-400",
    "retryable" => "fill-yellow-300",
    "scheduled" => "fill-green-400"
  }

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    lookback = 108
    step = 1

    timeslice =
      Met.timeslice(
        assigns.conf.name,
        assigns.series,
        by: step,
        lookback: lookback,
        group: assigns.group
      )

    {slices, max} =
      Enum.reduce(0..lookback, {[], 0}, fn idx, {acc, oldmax} ->
        tstamp = assigns.os_time - idx * step

        slices =
          timeslice
          |> Enum.filter(&(elem(&1, 0) == idx))
          |> Enum.concat(@empty_states)
          |> then(&:lists.ukeysort(3, &1))

        total = Enum.reduce(slices, 0, &(elem(&1, 1) + &2))

        {[{idx, tstamp, total, slices} | acc], max(total, oldmax)}
      end)

    socket =
      socket
      |> assign(height: 180, width: 1100, guides: 5)
      |> assign(max: max, slices: slices)
      |> assign(group: assigns.group, period: assigns.period, series: assigns.series)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-900 rounded-md shadow-md w-full mb-3">
      <div class="flex items-center justify-between p-3">
        <h3 class="flex items-center text-gray-900 dark:text-gray-200 text-base font-semibold">
          <Icons.chevron_down class="w-5 h-5 mr-2" />
          <%= metric_label(@series) %>
          <span class="text-gray-600 dark:text-gray-400 font-light ml-1">
            (<%= @period %> by <%= String.capitalize(@group) %>)
          </span>
        </h3>

        <div id="chart-c" class="flex space-x-2">
          <Core.dropdown_button
            name="series"
            title="Change series"
            selected={@series}
            options={~w(exec_count full_count exec_time wait_time)a}
          >
            <Icons.chart_bar_square />
          </Core.dropdown_button>

          <Core.dropdown_button
            name="period"
            title="Change period"
            selected="1s"
            options={~w(1s 5s 10s 30s 1m 2m)}
          >
            <Icons.clock />
          </Core.dropdown_button>

          <Core.dropdown_button
            name="group"
            title="Change group"
            selected="state"
            options={~w(state queue node worker)}
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
          <%= for {index, tstamp, _total, _values} <- @slices, Integer.mod(tstamp, 10) == 0 do %>
            <.tick index={index} total={10} tstamp={tstamp} width={@width - 20} />
          <% end %>
        </g>

        <g id="chart-d" transform="translate(24, 10)">
          <%= for {index, tstamp, total, values} <- @slices do %>
            <.col
              index={index}
              max={@max}
              total_height={@height}
              total_width={@width}
              total={total}
              tstamp={tstamp}
              values={values}
            />
          <% end %>
        </g>

        <g id="chart-tooltip" transform="translate(-100000)">
          <polygon class="fill-gray-800" points="0,8 8,0 16,8" transform="translate(52, 0)" />
          <rect rel="rect" class="fill-gray-800" height="112" width="120" rx="4" y="8" />
          <text rel="date" class="fill-gray-100 text-xs font-semibold tabular" x="6" y="26">
            00:00:00
          </text>

          <%= for {label, color} <- states_palette() do %>
            <g rel={label}>
              <circle class={color} cy="-4" r="4" />
              <text class="fill-gray-300 text-xs tabular capitalize" x="8">Cancelled</text>
            </g>
          <% end %>
        </g>
      </svg>
    </div>
    """
  end

  defp states_palette, do: @states_palette

  defp metric_label(:exec_count), do: "Executed"
  defp metric_label(:full_count), do: "Total"
  defp metric_label(:exec_time), do: "Execution Time"
  defp metric_label(:wait_time), do: "Queue Time"

  @doc false
  def guide_values(max, total) when max > 0 and total > 1 do
    top = ceil(max * 1.10 / 10) * 10
    step = div(top, total - 1)

    for num <- 0..top//step, do: integer_to_estimate(num)
  end

  def guide_values(0, total), do: guide_values(@default_guides_max, total)

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

      <%= for {value, label, y, height, color} <- build_stack(@values, @total, @inner_height, @total_height) do %>
        <rect class={color} width="9" y={y} height={height} data-label={label} data-value={value} />
      <% end %>
    </g>
    """
  end

  defp build_stack(_values, 0, _inner, _total), do: []

  defp build_stack(values, total_count, inner_height, total_height) do
    {stack, _y, _idx} =
      Enum.reduce(values, {[], 0, 0}, fn {_chk, value, label}, {acc, prev_y, idx} ->
        case value / total_count * inner_height do
          0.0 ->
            {acc, prev_y, idx + 1}

          height ->
            color = color_for(:states, idx, label)
            y = total_height - height - prev_y

            {[{value, label, y, height, color} | acc], prev_y + height, idx + 1}
        end
      end)

    stack
  end

  defp color_for(:states, _index, label), do: Map.fetch!(@states_palette, label)
end
