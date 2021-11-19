defmodule Oban.Web.RefreshComponent do
  use Oban.Web, :live_component

  alias Phoenix.LiveView.JS

  @refresh_options %{1 => "1s", 2 => "2s", 5 => "5s", 15 => "15s", 60 => "1m", -1 => "Off"}

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="refresh" class="flex items-center ml-auto" phx-hook="ToggleRefresh">
      <label
        id="listbox-label"
        class="text-sm font-medium text-gray-700 dark:text-gray-300 hidden md:block"
        data-title="Change background refresh rate"
        phx-hook="Tippy">
        Refresh
      </label>

      <div class="relative ml-2">
        <button
          class="relative w-16 bg-gray-50 dark:bg-gray-800 border border-gray-300 dark:border-gray-400 rounded-md shadow-sm pl-3 pr-10 py-2 text-left cursor-default focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          aria-haspopup="listbox"
          aria-expanded="true"
          aria-labelledby="listbox-label"
          type="button"
          phx-click={JS.toggle(to: "#refresh-menu")}>
          <span class="block text-gray-800 dark:text-gray-200"><%= format_option(@refresh) %></span>
          <span class="absolute inset-y-0 right-0 flex items-center pr-2 pointer-events-none">
            <svg class="h-5 w-5 text-gray-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M10 3a1 1 0 01.707.293l3 3a1 1 0 01-1.414 1.414L10 5.414 7.707 7.707a1 1 0 01-1.414-1.414l3-3A1 1 0 0110 3zm-3.707 9.293a1 1 0 011.414 0L10 14.586l2.293-2.293a1 1 0 011.414 1.414l-3 3a1 1 0 01-1.414 0l-3-3a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
          </span>
        </button>

        <ul id="refresh-menu" class="hidden absolute z-10 mt-1 w-16 bg-gray-50 dark:bg-gray-800 shadow-lg max-h-60 rounded-md text-base ring-1 ring-blue-400 ring-opacity-5 overflow-auto focus:outline-none sm:text-sm" tabindex="-1" role="listbox" aria-labelledby="listbox-label" aria-activedescendant="listbox-option-3">
          <%= for {option, display} <- refresh_options() do %>
            <li class="relative text-gray-800 dark:text-gray-200 cursor-pointer select-none hover:bg-blue-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25 py-2 pl-8 pr-4"
              role="option"
              value={option}
              phx-click="select-refresh"
              phx-target={@myself}
              phx-click-away={JS.hide(to: "#refresh-menu")}>
              <span class={"block #{if option == @refresh, do: "font-semibold", else: "font-normal"}"}><%= display %></span>

              <span class={"text-blue-500 absolute inset-y-0 left-0 flex items-center pl-1.5 #{if option != @refresh, do: "hidden"}"}>
                <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
                </svg>
              </span>
            </li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("select-refresh", %{"value" => value}, socket) do
    send(self(), {:update_refresh, value})

    {:noreply, socket}
  end

  def handle_event("pause-refresh", _params, socket) do
    send(self(), :pause_refresh)

    {:noreply, socket}
  end

  def handle_event("resume-refresh", _params, socket) do
    send(self(), :resume_refresh)

    {:noreply, socket}
  end

  # Helpers

  defp format_option(value), do: Map.get(@refresh_options, value)

  defp refresh_options, do: @refresh_options
end
