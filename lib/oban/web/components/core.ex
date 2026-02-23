defmodule Oban.Web.Components.Core do
  use Oban.Web, :html

  attr :click, :string, required: true
  attr :danger, :boolean, default: false
  attr :disabled, :boolean, default: false
  attr :label, :string, required: true
  attr :target, :any
  slot :icon
  slot :title

  def action_button(assigns) do
    class =
      cond do
        assigns.disabled ->
          "text-gray-400"

        assigns.danger ->
          "text-red-500 group-hover:text-red-600 hover:bg-gray-100 dark:hover:bg-gray-950"

        true ->
          "text-gray-500 group-hover:text-gray-600 hover:bg-gray-100 dark:hover:bg-gray-950"
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <button
      class={["flex items-center space-x-2 px-3 py-1.5 rounded-md text-sm", @class]}
      data-title={render_slot(@title)}
      disabled={@disabled}
      id={@click}
      phx-click={@click}
      phx-hook="Tippy"
      phx-target={@target}
      type="button"
    >
      {render_slot(@icon)}
      <span class="block">{@label}</span>
    </button>
    """
  end

  @doc """
  A numerical input with increment and decrement buttons.
  """
  def number_input(assigns) do
    ~H"""
    <div>
      <%= if @label do %>
        <label
          for={@name}
          class={"block font-medium text-sm mb-2 #{if @disabled, do: "text-gray-600 dark:text-gray-400", else: "opacity-50"}"}
        >
          {@label}
        </label>
      <% end %>

      <div class="flex">
        <input
          autocomplete="off"
          class="w-1/2 flex-1 min-w-0 block font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-800 disabled:opacity-50 rounded-l-md focus:ring-blue-400 focus:border-blue-400"
          disabled={@disabled}
          inputmode="numeric"
          name={@name}
          pattern="[1-9][0-9]*"
          placeholder="Off"
          type="text"
          value={@value}
        />

        <div class="w-9">
          <button
            rel="inc"
            class="block -ml-px px-3 py-1 bg-gray-300 dark:bg-gray-500 rounded-tr-md hover:bg-gray-200 dark:hover:bg-gray-600 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 cursor-pointer disabled:opacity-50 disabled:pointer-events-none"
            disabled={@disabled}
            type="button"
            phx-click="increment"
            phx-target={@myself}
            phx-value-field={@name}
          >
            <Icons.chevron_up class="w-3 h-3 text-gray-600 dark:text-gray-200" />
          </button>

          <button
            rel="dec"
            class="block -ml-px px-3 py-1 bg-gray-300 dark:bg-gray-500 rounded-br-md hover:bg-gray-200 dark:hover:bg-gray-600 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 cursor-pointer disabled:opacity-50 disabled:pointer-events-none"
            disabled={@disabled}
            tabindex="-1"
            type="button"
            phx-click="decrement"
            phx-target={@myself}
            phx-value-field={@name}
          >
            <Icons.chevron_down class="w-3 h-3 text-gray-600 dark:text-gray-200" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  slot :inner_block, required: true
  attr :name, :string, required: true
  attr :options, :list, required: true
  attr :selected, :any, required: true
  attr :title, :string, required: true
  attr :disabled, :boolean, default: false
  attr :target, :any, default: "myself"

  def dropdown_button(assigns) do
    ~H"""
    <div class="relative" id={"#{@name}-selector"}>
      <button
        aria-expanded="true"
        aria-haspopup="listbox"
        class="text-gray-500 dark:text-gray-400 disabled:text-gray-400 disabled:dark:text-gray-500 focus:outline-none hover:text-gray-800 dark:hover:text-gray-200 hidden md:block"
        data-title={@title}
        disabled={@disabled}
        id={"#{@name}-menu-toggle"}
        phx-hook="Tippy"
        phx-click={JS.toggle(to: "##{@name}-menu")}
        type="button"
      >
        {render_slot(@inner_block)}
      </button>

      <ul
        class="hidden absolute z-50 top-full right-0 mt-2 w-32 overflow-hidden border border-gray-100 dark:border-gray-800 rounded-md shadow-md text-sm font-semibold bg-white dark:bg-gray-800 focus:outline-none"
        id={"#{@name}-menu"}
        role="listbox"
        tabindex="-1"
      >
        <%= for option <- @options do %>
          <.dropdown_option name={@name} value={option} selected={@selected} target={@target} />
        <% end %>
      </ul>
    </div>
    """
  end

  attr :name, :any, required: true
  attr :value, :any, required: true
  attr :selected, :any, required: true
  attr :target, :any

  defp dropdown_option(assigns) do
    class =
      if assigns.selected == assigns.value do
        "text-blue-500 dark:text-blue-400"
      else
        "text-gray-500 dark:text-gray-400 "
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <li
      class={"block w-full py-1 px-2 flex items-center cursor-pointer select-none space-x-2 hover:bg-gray-50 hover:dark:bg-gray-600/30 #{@class}"}
      id={"select-#{@name}-#{@value}"}
      role="option"
      phx-click={"select-#{@name}"}
      phx-click-away={JS.hide(to: "##{@name}-menu")}
      phx-target={@target}
      phx-value-choice={@value}
    >
      <%= if to_string(@value) == to_string(@selected) do %>
        <Icons.check class="w-5 h-5" />
      <% else %>
        <span class="block w-5 h-5"></span>
      <% end %>

      <span class="capitalize text-gray-800 dark:text-gray-200">
        {@value |> to_string() |> String.replace("_", " ")}
      </span>
    </li>
    """
  end

  attr :checked, :boolean, default: false
  attr :click, :string, required: true
  attr :myself, :any, required: true
  attr :value, :string, required: true

  def row_checkbox(assigns) do
    style =
      if assigns.checked do
        "border-blue-500 bg-blue-500"
      else
        "border-gray-400 dark:border-gray-600 group-hover:bg-gray-400 dark:group-hover:bg-gray-600"
      end

    assigns = assign(assigns, :style, style)

    ~H"""
    <button
      class="p-6 group"
      phx-click={@click}
      phx-target={@myself}
      phx-value-id={@value}
      rel="check"
    >
      <div class={["w-4 h-4 flex items-center justify-center rounded border", @style]}>
        <Icons.check class="w-3 h-3 text-white dark:text-gray-900" />
      </div>
    </button>
    """
  end

  attr :checked, :atom, required: true
  attr :click, :string, required: true
  attr :myself, :any, required: true

  def all_checkbox(assigns) do
    style =
      if assigns.checked in [:all, :some] do
        "border-blue-500 bg-blue-500"
      else
        "border-gray-400 dark:border-gray-600 group-hover:bg-gray-400 dark:group-hover:bg-gray-600"
      end

    assigns = assign(assigns, :style, style)

    ~H"""
    <button
      class="p-6 group"
      data-title="Select All"
      id="toggle-select"
      phx-click={@click}
      phx-hook="Tippy"
      phx-target={@myself}
      type="button"
    >
      <div class={["w-4 h-4 flex items-center justify-center rounded border", @style]}>
        <%= if @checked == :some do %>
          <Icons.indeterminate class="w-3 h-3 text-white dark:text-gray-900" />
        <% else %>
          <Icons.check class="w-3 h-3 text-white dark:text-gray-900" />
        <% end %>
      </div>
    </button>
    """
  end

  @doc """
  A status badge with icon that expands to show label on hover.
  """
  attr :icon, :string, required: true
  attr :id, :string, default: nil
  attr :label, :string, required: true

  def status_badge(assigns) do
    ~H"""
    <div id={@id} class="group flex items-center cursor-default select-none">
      <span class="inline-flex items-center justify-center h-9 pl-2.5 pr-2.5 group-hover:pr-4 rounded-full text-sm font-medium bg-violet-100 text-violet-700 dark:bg-violet-700/70 dark:text-violet-200 transition-all duration-200">
        <.badge_icon name={@icon} />
        <span class="max-w-0 overflow-hidden group-hover:max-w-24 group-hover:ml-1.5 transition-all duration-200 whitespace-nowrap">
          {@label}
        </span>
      </span>
    </div>
    """
  end

  defp badge_icon(%{name: "camera"} = assigns), do: ~H[<Icons.camera class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "life_buoy"} = assigns),
    do: ~H[<Icons.life_buoy class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "lock_closed"} = assigns),
    do: ~H[<Icons.lock_closed class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "sparkles"} = assigns),
    do: ~H[<Icons.sparkles class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "table_cells"} = assigns),
    do: ~H[<Icons.table_cells class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "square_2x2"} = assigns),
    do: ~H[<Icons.square_2x2 class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "rectangle_group"} = assigns),
    do: ~H[<Icons.rectangle_group class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "user_group"} = assigns),
    do: ~H[<Icons.user_group class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "link"} = assigns),
    do: ~H[<Icons.link class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "power"} = assigns),
    do: ~H[<Icons.power class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "pause_circle"} = assigns),
    do: ~H[<Icons.pause_circle class="h-4 w-4 shrink-0" />]

  defp badge_icon(%{name: "play_pause_circle"} = assigns),
    do: ~H[<Icons.play_pause_circle class="h-4 w-4 shrink-0" />]

  @doc """
  An icon-only button that expands to show label on hover. Supports disabled state.
  """
  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :color, :string, required: true
  attr :disabled, :boolean, default: false
  attr :confirm, :string, default: nil
  attr :tooltip, :string, default: nil
  attr :rest, :global

  def icon_button(assigns) do
    color_classes =
      case {assigns.color, assigns.disabled} do
        {_, true} ->
          "text-gray-400 dark:text-gray-500 bg-gray-100 dark:bg-gray-800 border-gray-200 dark:border-gray-700 cursor-not-allowed"

        {"yellow", false} ->
          "text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-700 cursor-pointer hover:text-yellow-600 hover:border-yellow-600"

        {"blue", false} ->
          "text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-700 cursor-pointer hover:text-blue-500 hover:border-blue-600"

        {"red", false} ->
          "text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-700 cursor-pointer hover:text-red-500 hover:border-red-600"

        {"violet", false} ->
          "text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-700 cursor-pointer hover:text-violet-500 hover:border-violet-600"
      end

    icon_color =
      if assigns.disabled do
        "text-gray-400 dark:text-gray-500"
      else
        case assigns.color do
          "yellow" -> "text-gray-500 group-hover:text-yellow-500"
          "blue" -> "text-gray-500 group-hover:text-blue-500"
          "red" -> "text-gray-500 group-hover:text-red-500"
          "violet" -> "text-gray-500 group-hover:text-violet-500"
        end
      end

    assigns = assign(assigns, color_classes: color_classes, icon_color: icon_color)

    ~H"""
    <button
      id={@id}
      type="button"
      disabled={@disabled}
      data-confirm={@confirm}
      data-title={@tooltip}
      phx-hook={if @tooltip, do: "Tippy"}
      class={[
        "group inline-flex items-center justify-center h-9 pl-2.5 pr-2.5 rounded-md border text-sm font-medium transition-all duration-200",
        unless(@disabled, do: "group-hover:pr-3"),
        @color_classes
      ]}
      {@rest}
    >
      <.button_icon name={@icon} class={["h-5 w-5 shrink-0", @icon_color]} />
      <span class={[
        "overflow-hidden transition-all duration-200 whitespace-nowrap",
        if(@disabled, do: "max-w-0", else: "max-w-0 group-hover:max-w-24 group-hover:ml-1.5")
      ]}>
        {@label}
      </span>
    </button>
    """
  end

  defp button_icon(%{name: "arrow_path"} = assigns), do: ~H[<Icons.arrow_path class={@class} />]

  defp button_icon(%{name: "pause_circle"} = assigns),
    do: ~H[<Icons.pause_circle class={@class} />]

  defp button_icon(%{name: "pencil_square"} = assigns),
    do: ~H[<Icons.pencil_square class={@class} />]

  defp button_icon(%{name: "play_circle"} = assigns), do: ~H[<Icons.play_circle class={@class} />]
  defp button_icon(%{name: "trash"} = assigns), do: ~H[<Icons.trash class={@class} />]
  defp button_icon(%{name: "x_circle"} = assigns), do: ~H[<Icons.x_circle class={@class} />]

  # Sparkline

  attr :id, :string, required: true
  attr :history, :map, required: true
  attr :max_value, :integer, default: nil
  attr :bar_width, :integer, default: 4
  attr :count, :integer, default: 60
  attr :gap, :integer, default: 1
  attr :height, :integer, default: 16
  attr :class, :string, default: nil

  def sparkline(assigns) do
    history = assigns.history
    count = assigns.count
    bar_width = assigns.bar_width
    gap = assigns.gap
    height = assigns.height
    max_index = count - 1

    max_value =
      if assigns.max_value do
        max(assigns.max_value, 1)
      else
        history
        |> Map.values()
        |> Enum.reduce(1, fn %{count: c}, acc -> max(c, acc) end)
      end

    now = System.system_time(:millisecond)

    {bars, tooltip_data} =
      for slot <- 0..max_index, reduce: {[], []} do
        {bars_acc, tool_acc} ->
          index = max_index - slot
          timestamp = now - index * 5 * 1000
          x = slot * (bar_width + gap)

          case Map.get(history, index) do
            %{count: c} ->
              bar_height = min(c / max_value, 1.0) * height
              bar = %{x: x, height: max(bar_height, 0)}
              tooltip = %{timestamp: timestamp, count: c}

              {[bar | bars_acc], [tooltip | tool_acc]}

            nil ->
              tooltip = %{timestamp: timestamp, count: 0}

              {bars_acc, [tooltip | tool_acc]}
          end
      end

    bars = Enum.reverse(bars)
    tooltip_data = Enum.reverse(tooltip_data)

    placeholders =
      for slot <- 0..max_index do
        %{x: slot * (bar_width + gap)}
      end

    width = count * (bar_width + gap)

    assigns =
      assigns
      |> assign(bars: bars, placeholders: placeholders, width: width)
      |> assign(tooltip_data: tooltip_data)

    ~H"""
    <svg
      id={@id}
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      class={["flex-shrink-0", @class]}
      phx-hook="QueueSparkline"
      data-tooltip={Oban.JSON.encode!(@tooltip_data)}
      data-bar-width={@bar_width}
    >
      <rect
        :for={placeholder <- @placeholders}
        x={placeholder.x}
        y={@height - 2}
        width={@bar_width}
        height="2"
        fill="#e5e7eb"
        class="dark:fill-gray-700"
        rx="0.5"
      />
      <rect
        :for={bar <- @bars}
        x={bar.x}
        y={@height - bar.height}
        width={@bar_width}
        height={bar.height}
        fill="#22d3ee"
        rx="1"
      />
    </svg>
    """
  end
end
