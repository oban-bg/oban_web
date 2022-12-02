defmodule Oban.Web.Components.Refresh do
  use Oban.Web, :live_component

  @options [
    {01, "1s"},
    {02, "2s"},
    {05, "5s"},
    {15, "15s"},
    {60, "1m"},
    {-1, "Off"}
  ]

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, :options, @options)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="relative" id="refresh-selector" phx-hook="Refresher">
      <button
        aria-haspopup="listbox"
        aria-expanded="true"
        aria-labelledby="listbox-label"
        class="text-slate-500 dark:text-slate-400 focus:outline-none hover:text-slate-600 dark:hover:text-slate-300 hidden md:block"
        data-title="Change refresh rate"
        id="refresh-menu-toggle"
        phx-hook="Tippy"
        phx-click={JS.toggle(to: "#refresh-menu")}
        type="button"
      >
        <%= if @refresh == -1 do %>
          <Icons.pause_circle />
        <% else %>
          <Icons.clock />
        <% end %>
      </button>

      <ul
        class="hidden absolute z-50 top-full right-0 mt-2 w-18 py-1 overflow-hidden rounded-lg shadow-lg ring-1 ring-blue-400 ring-opacity-5 text-sm font-semibold bg-white dark:bg-slate-800 focus:outline-none"
        id="refresh-menu"
        role="listbox"
        tabindex="-1"
      >
        <%= for {value, display} <- @options do %>
          <.option value={value} display={display} refresh={@refresh} />
        <% end %>
      </ul>
    </div>
    """
  end

  attr :refresh, :integer, required: true
  attr :value, :integer, required: true
  attr :display, :string, required: true

  defp option(assigns) do
    class =
      if assigns.refresh == assigns.value do
        "text-blue-500 dark:text-blue-400"
      else
        "text-slate-500 dark:text-slate-400 "
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <li
      class={"block w-full py-1 px-2 flex items-center cursor-pointer select-none space-x-2 hover:bg-slate-50 hover:dark:bg-slate-600/30 #{@class}"}
      role="option"
      value={@value}
      phx-click="select-refresh"
      phx-click-away={JS.hide(to: "#refresh-menu")}
      phx-target="#refresh-selector"
    >
      <%= if @value == @refresh do %>
        <Icons.check class="w-5 h-5" />
      <% else %>
        <span class="block w-5 h-5"></span>
      <% end %>

      <span class="text-slate-800 dark:text-slate-200"><%= @display %></span>
    </li>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("select-refresh", %{"value" => value}, socket) do
    value = if is_binary(value), do: String.to_integer(value), else: value

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
end
