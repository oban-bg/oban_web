defmodule Oban.Web.Live.Chart do
  use Oban.Web, :live_component

  alias Oban.Met

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    timeslice =
      assigns.conf.name
      |> Met.timeslice(:exec_count, by: 1, lookback: 90)
      |> Enum.group_by(&elem(&1, 0), &Tuple.delete_at(&1, 0))
      |> Enum.sort(:asc)

    max =
      timeslice
      |> Enum.map(fn {_ts, vals} -> slice_total(vals) end)
      |> Enum.max()

    guides =
      max
      |> div(20)
      |> min(5)
      |> max(4)

    {:ok,
     assign(socket, height: 180, guides: guides, max: max, timeslice: timeslice, width: 1100)}
  end

  # <g fill="none" font-size="10" text-anchor="end">
  #   <g class="tick" transform="translate(0, 175.5)">
  #     <line x2="1110" />
  #     <text x="-3" dy="0.32em">0</text>
  #   </g>
  # </g>

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-900 rounded-md shadow-md overflow-hidden w-full mb-3">
      <div class="flex justify-between p-3">
        <h3 class="dark:text-gray-200 text-sm font-semibold">Executed by State</h3>
        <div class="flex space-x-2 text-gray-400">
          <Icons.chart_bar_square />
          <Icons.calendar_days />
          <Icons.rectangle_group />
        </div>
      </div>

      <svg class="w-full" height="200">
        <g fill="currentColor" transform="translate(0, 10)" text-anchor="end">
          <%= for {label, index} <- Enum.with_index(guide_values(@max, @guides)) do %>
            <line
              class="text-gray-300 dark:text-gray-700"
              stroke="currentColor"
              stroke-dasharray="4,4"
              y1={@height - index * div(@height, @guides)}
              y2={@height - index * div(@height, @guides)}
              x1="42"
              x2={@width + 20}
            />
            <text
              class="text-gray-400 text-sm tabular"
              x="36"
              y={@height + 8 - (index * div(@height, @guides) + @guides)}
            >
              <%= if index == 0, do: "", else: label %>
            </text>
          <% end %>
        </g>

        <g transform="translate(24, 10)">
          <g class="fill-gray-600">
            <%= for {slice, index} <- Enum.with_index(@timeslice) do %>
              <.col
                index={index}
                max={@max}
                total_height={@height}
                total_width={@width}
                slice={slice}
              />
            <% end %>
          </g>
        </g>
      </svg>
    </div>
    """
  end

  @doc false
  def guide_values(max, total) when max > 0 and total > 1 do
    top = ceil(max * 1.25 / 10) * 10
    step = div(top, total)

    for num <- 0..top//step, do: integer_to_estimate(num)
  end

  defp col(assigns) do
    height = trunc(slice_total(assigns.slice) / assigns.max * assigns.total_height - 10)

    assigns = assign(assigns, height: height)

    ~H"""
    <rect x={@total_width - 10 - @index * 10} y={@total_height - @height} width="9" height={@height} />
    """
  end

  # Helpers

  defp slice_total({_ts, slice}), do: slice_total(slice)

  defp slice_total(slice) when is_list(slice) do
    Enum.reduce(slice, 0, fn {count, _label}, acc -> acc + count end)
  end
end
