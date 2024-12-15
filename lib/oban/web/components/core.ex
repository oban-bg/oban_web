defmodule Oban.Web.Components.Core do
  use Oban.Web, :html

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
          class="w-1/2 flex-1 min-w-0 block font-mono text-sm shadow-sm border-gray-300 dark:border-gray-500 bg-gray-50 dark:bg-gray-800 disabled:opacity-50 rounded-l-md focus:ring-blue-400 focus:border-blue-400"
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

  @doc """
  A queue specific pause/resume button.
  """
  def pause_button(assigns) do
    assigns =
      assigns
      |> assign_new(:id, fn -> "play-pause-#{assigns.myself}" end)
      |> assign_new(:title, fn -> if assigns.paused, do: "Resume queue", else: "Pause queue" end)

    ~H"""
    <button
      rel="toggle-pause"
      class="block text-gray-400 dark:text-gray-600 hover:text-blue-500 dark:hover:text-blue-500"
      disabled={@disabled}
      id={@id}
      data-title={@title}
      type="button"
      phx-click={@click}
      phx-target={@myself}
      phx-throttle="2000"
      phx-hook="Tippy"
    >
      <%= if @paused do %>
        <Icons.play_circle_solid class="w-5 h-5" />
      <% else %>
        <Icons.pause_circle_solid class="w-5 h-5" />
      <% end %>
    </button>
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
        class="text-gray-500 dark:text-gray-400 disabled:text-gray-400 disabled:dark:text-gray-600 focus:outline-none hover:text-gray-800 dark:hover:text-gray-200 hidden md:block"
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
          <.option name={@name} value={option} selected={@selected} target={@target} />
        <% end %>
      </ul>
    </div>
    """
  end

  attr :name, :any, required: true
  attr :value, :any, required: true
  attr :selected, :any, required: true
  attr :target, :any

  defp option(assigns) do
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
end
