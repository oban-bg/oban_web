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
      {"border-yellow-400", "bg-yellow-400/10", "text-yellow-600 dark:text-yellow-400"},
    "executing" =>
      {"border-emerald-400", "bg-emerald-400/10", "text-emerald-600 dark:text-emerald-400"},
    "completed" => {"border-cyan-400", "bg-cyan-400/10", "text-cyan-600 dark:text-cyan-400"},
    "cancelled" =>
      {"border-violet-400", "bg-violet-400/10", "text-violet-600 dark:text-violet-400"},
    "discarded" => {"border-rose-400", "bg-rose-400/10", "text-rose-600 dark:text-rose-400"}
  }

  @inactive_classes {
    "border-gray-300 dark:border-gray-600",
    "bg-gray-100 dark:bg-gray-800",
    "text-gray-400 dark:text-gray-500"
  }

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
