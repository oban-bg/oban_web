defmodule Oban.Web.Live.Chart do
  use Oban.Web, :live_component

  alias Oban.Met

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    timeslice =
      assigns.conf.name
      |> Met.timeslice(:exec_counts, by: 1, lookback: div(1080, 10))
      |> Enum.group_by(&elem(&1, 0), &Tuple.delete_at(&1, 0))
      |> Enum.sort(:asc)

    max =
      timeslice
      |> Enum.map(fn {_ts, vals} -> slice_total(vals) end)
      |> Enum.max()
      |> max(20)

    guides =
      max
      |> div(20)
      |> min(5)
      |> max(3)

    {:ok,
     assign(socket, height: 140, guides: guides, max: max, timeslice: timeslice, width: 1080)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="w-full flex">
      <svg class="w-full" height="160">
        <g fill="currentColor" transform="translate(0, 10)">
          <%= for {label, index} <- Enum.with_index(guide_values(@max, @guides)) do %>
            <line
              class="text-gray-800"
              stroke="currentColor"
              y1={index * div(@height, @guides)}
              y2={index * div(@height, @guides)}
              x1="24"
              x2={@width + 24}
            />
            <text
              class="text-gray-400 text-xs tabular"
              y={index * div(@height, @guides) + @guides - 1}
            >
              <%= label %>
            </text>
          <% end %>
        </g>

        <g transform="translate(24, 10)">
          <rect
            class="text-gray-700"
            width={@width}
            height={@height}
            stroke="currentColor"
            fill="none"
          />

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

      <span class="text-gray-500 dark:text-gray-400">
        <Icons.adjustments_vertical />
      </span>
    </div>
    """
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

  defp guide_values(max, total) do
    top = ceil(max * 1.10 / 10) * 10

    top..0//div(top, -total)
  end
end
