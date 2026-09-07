defmodule Oban.Web.Colors do
  @moduledoc false

  # Hex colors for SVGs and inline styles (must match assets/js/lib/colors.js)
  @hex %{
    blue: "#60a5fa",
    cyan: "#22d3ee",
    emerald: "#34d399",
    gray: "#9ca3af",
    indigo: "#818cf8",
    rose: "#fb7185",
    violet: "#a78bfa",
    yellow: "#facc15"
  }

  # State to color name mapping
  @state_color_names %{
    "suspended" => :gray,
    "scheduled" => :indigo,
    "available" => :blue,
    "retryable" => :yellow,
    "executing" => :emerald,
    "completed" => :cyan,
    "cancelled" => :violet,
    "discarded" => :rose
  }

  # Tailwind classes per state for templates
  @state_classes %{
    "suspended" => {"border-gray-400", "bg-gray-400/10", "text-gray-600 dark:text-gray-400"},
    "scheduled" =>
      {"border-indigo-400", "bg-indigo-400/10", "text-indigo-600 dark:text-indigo-400"},
    "available" => {"border-blue-400", "bg-blue-400/10", "text-blue-600 dark:text-blue-400"},
    "retryable" =>
      {"border-yellow-400", "bg-yellow-400/10", "text-yellow-700 dark:text-yellow-400"},
    "executing" =>
      {"border-emerald-400", "bg-emerald-400/10", "text-emerald-700 dark:text-emerald-400"},
    "completed" => {"border-cyan-400", "bg-cyan-400/10", "text-cyan-700 dark:text-cyan-400"},
    "cancelled" =>
      {"border-violet-400", "bg-violet-400/10", "text-violet-600 dark:text-violet-400"},
    "discarded" => {"border-rose-400", "bg-rose-400/10", "text-rose-600 dark:text-rose-400"}
  }

  @inactive_classes {
    "border-gray-300 dark:border-gray-600",
    "bg-gray-100 dark:bg-gray-800",
    "text-gray-400 dark:text-gray-500"
  }

  # Hues for series that aren't job states, e.g. queues or workers in a chart. None of these
  # appear in the state palette so a queue can never be mistaken for a state.
  @series_palette ~w(orange teal fuchsia lime sky pink amber red)a

  @series_hex %{
    amber: "#fbbf24",
    fuchsia: "#e879f9",
    gray: "#9ca3af",
    lime: "#a3e635",
    orange: "#fb923c",
    pink: "#f472b6",
    red: "#f87171",
    sky: "#38bdf8",
    teal: "#2dd4bf"
  }

  # Spelled out so Tailwind sees each class.
  @series_bg_classes %{
    amber: "bg-amber-400",
    fuchsia: "bg-fuchsia-400",
    gray: "bg-gray-400",
    lime: "bg-lime-400",
    orange: "bg-orange-400",
    pink: "bg-pink-400",
    red: "bg-red-400",
    sky: "bg-sky-400",
    teal: "bg-teal-400"
  }

  @doc """
  Assign a stable color name to each label from the non-state palette.

  Colors are chosen by hashing the label, so a label keeps its color regardless of which other
  labels are present. When two labels hash to the same slot the later one (sorted) walks to the
  next free slot.
  """
  def series_colors(labels) do
    size = length(@series_palette)

    labels
    |> Enum.sort()
    |> Enum.reduce({%{}, MapSet.new()}, fn label, {colors, used} ->
      start = :erlang.phash2(label, size)

      slot =
        0..(size - 1)
        |> Stream.map(&rem(start + &1, size))
        |> Enum.find(start, &(not MapSet.member?(used, &1)))

      {Map.put(colors, label, Enum.at(@series_palette, slot)), MapSet.put(used, slot)}
    end)
    |> elem(0)
  end

  @doc """
  Returns the hex color for a series color name.
  """
  def series_hex(name), do: Map.fetch!(@series_hex, name)

  @doc """
  Returns the background class for a series color name (e.g., "bg-orange-400").
  """
  def series_bg_class(name), do: Map.fetch!(@series_bg_classes, name)

  @doc """
  Returns the hex color for a state (for SVGs and inline styles).
  """
  def state_hex(state) when is_binary(state) do
    color_name = Map.get(@state_color_names, state, :gray)
    Map.fetch!(@hex, color_name)
  end

  def state_hex(_state), do: Map.fetch!(@hex, :gray)

  @doc """
  Returns Tailwind classes for a state: {border, background, text}.
  """
  def state_classes(state) when is_binary(state) do
    Map.get(@state_classes, state, @inactive_classes)
  end

  def state_classes(_state), do: @inactive_classes

  @doc """
  Returns Tailwind classes for inactive state.
  """
  def inactive_classes, do: @inactive_classes

  @doc """
  Returns the background class for a state (e.g., "bg-cyan-400").
  """
  def state_bg_class(state) when is_binary(state) do
    color_name = Map.get(@state_color_names, state, :gray)
    "bg-#{color_name}-400"
  end

  def state_bg_class(_state), do: "bg-gray-400"

  @doc """
  Returns the text class for a state (e.g., "text-cyan-400").
  """
  def state_text_class(state) when is_binary(state) do
    color_name = Map.get(@state_color_names, state, :gray)
    "text-#{color_name}-400"
  end

  def state_text_class(_state), do: "text-gray-400"
end
