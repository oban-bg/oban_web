defmodule Oban.Web.Components.Core do
  @moduledoc false

  use Phoenix.Component

  alias Oban.Web.Components.Icons

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
          <%= @label %>
        </label>
      <% end %>

      <div class="flex">
        <input
          autocomplete="off"
          class="w-1/2 flex-1 min-w-0 block font-mono text-sm shadow-sm border-gray-300 dark:border-gray-500 bg-gray-50 dark:bg-gray-800 disabled:opacity-50 rounded-l-md focus:ring-blue-400 focus:border-blue-400"
          disabled={@disabled}
          id={@name}
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
    ~H"""
    <button
      rel="toggle-pause"
      class={"block hover:text-blue-500 #{if @paused, do: "text-red-500", else: "text-gray-500"}"}
      disabled={@disabled}
      id={"play-pause-#{@myself}"}
      data-title={if @paused, do: "Resume queue", else: "Pause queue"}
      type="button"
      phx-click={@click}
      phx-target={@myself}
      phx-throttle="2000"
      phx-hook="Tippy"
    >
      <%= if @paused do %>
        <Icons.pause_circle class="w-5 h-5" />
      <% else %>
        <Icons.play_circle class="w-5 h-5" />
      <% end %>
    </button>
    """
  end
end
