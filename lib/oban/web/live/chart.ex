defmodule Oban.Web.Live.Chart do
  use Oban.Web, :live_component

  alias Oban.Met

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    groupings =
      assigns.conf.name
      |> Met.timeslice(:executing, by: 1, label: "queue", lookback: 90)
      |> Enum.group_by(&elem(&1, 0), &Tuple.delete_at(&1, 0))

    timeslice =
      0..90//1
      |> Enum.map(fn step ->
        ts = assigns.system_time - step

        {ts, Map.get(groupings, ts, [])}
      end)
      |> Enum.reverse()

    {min, max} =
      timeslice
      |> Enum.map(fn {_ts, vals} -> slice_total(vals) end)
      |> Enum.min_max()

    {:ok, assign(socket, min: min, max: max, timeslice: timeslice)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <svg class="w-full" height="160">
      <rect class="text-slate-700" width="1090" height="140" stroke="currentColor" fill="none" />

      <g class="text-slate-400" fill="currentColor">
        <%= for {slice, index} <- Enum.with_index(@timeslice) do %>
          <.col index={index} max={@max} slice={slice} />
        <% end %>
      </g>
    </svg>
    """
  end

  defp col(assigns) do
    height = trunc((slice_total(assigns.slice) / assigns.max) * 140 - 10)

    assigns = assign(assigns, height: height)

    ~H"""
    <rect x={@index * 10 + (2 * @index)} y={140 - @height} width="10" height={@height}  />
    """
  end

  defp slice_total({_ts, slice}), do: slice_total(slice)

  defp slice_total(slice) when is_list(slice) do
    Enum.reduce(slice, 0, fn {count, _label}, acc -> acc + count end)
  end
end
