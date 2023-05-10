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
        group: "state"
      )

    {slices, max} =
      Enum.reduce(0..lookback, {[], 0}, fn idx, {acc, oldmax} ->
        tstamp = assigns.system_time - idx * step

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
      |> assign(height: 180, width: 1100)
      |> assign(guides: 5, max: max, slices: slices)
      |> assign(group: assigns.group, series: assigns.series, slice: assigns.slice)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-900 rounded-md shadow-md overflow-hidden w-full mb-3">
      <div class="flex items-center justify-between p-3">
        <h3 class="flex items-center text-gray-900 dark:text-gray-200 text-base font-semibold">
          <Icons.chevron_down class="w-5 h-5 mr-2" /> Executed
          <span class="text-gray-600 dark:text-gray-400 font-light ml-1">(Past 90s, by State)</span>
        </h3>

        <div class="flex space-x-2">
          <Core.dropdown_button
            name="metric"
            title="Change metric"
            selected="executed"
            options={~w(exec full wait)}
          >
            <Icons.chart_bar_square />
          </Core.dropdown_button>

          <Core.dropdown_button
            name="period"
            title="Change period"
            selected="1s"
            options={~w(1s 5m 1h)}
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
            selected="95"
            options={~w(99 95 75 50)}
          >
            <Icons.receipt_percent />
          </Core.dropdown_button>
        </div>
      </div>

      <svg class="w-full" height="200">
        <%= for {label, index} <- Enum.with_index(guide_values(@max, @guides)) do %>
          <g
            fill="currentColor"
            transform={"translate(42, #{@height + 10 - index * div(@height, @guides - 1)})"}
            text-anchor="end"
          >
            <line
              class="text-gray-300 dark:text-gray-700"
              stroke="currentColor"
              stroke-dasharray="4,4"
              x2={@width - 20}
            />
            <text class="text-gray-600 text-xs tabular" x="-4" dy="0.32em"><%= label %></text>
          </g>
        <% end %>

        <g transform="translate(24, 10)">
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
      </svg>
    </div>
    """
  end

  @doc false
  def guide_values(max, total) when max > 0 and total > 1 do
    top = ceil(max * 1.10 / 10) * 10
    step = div(top, total - 1)

    for num <- 0..top//step, do: integer_to_estimate(num)
  end

  def guide_values(0, total), do: guide_values(@default_guides_max, total)

  @states_palette %{
    "cancelled" => "fill-violet-400",
    "completed" => "fill-cyan-400",
    "discarded" => "fill-pink-400",
    "retryable" => "fill-yellow-300",
    "scheduled" => "fill-green-400"
  }

  defp color_for(:states, _index, label), do: Map.fetch!(@states_palette, label)

  defp col(assigns) do
    inner_height = trunc(assigns.total / assigns.max * assigns.total_height * 0.9)
    offset = assigns.total_width - 10 - assigns.index * 10

    assigns = assign(assigns, inner_height: inner_height, offset: offset)

    ~H"""
    <g class="group" id={"col-#{@tstamp}"} transform={"translate(#{@offset}, 0)"}>
      <rect class="fill-transparent group-hover:fill-gray-200" width="9" height={@total_height} />

      <%= for {y, height, color} <- build_stack(@values, @total, @inner_height, @total_height) do %>
        <rect class={color} width="9" y={y} height={height} />
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

            {[{y, height, color} | acc], prev_y + height, idx + 1}
        end
      end)

    stack
  end
end
