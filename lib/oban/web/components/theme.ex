defmodule Oban.Web.Components.Theme do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, :theme, "system")}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="relative" id="theme-selector" phx-hook="RestoreTheme">
      <button
        aria-expanded="true"
        aria-haspopup="listbox"
        aria-labelledby="listbox-label"
        class="text-slate-500 dark:text-slate-400 focus:outline-none hover:text-slate-600 dark:hover:text-slate-300 hidden md:block"
        data-title="Toggle theme"
        id="theme-menu-toggle"
        phx-hook="Tippy"
        phx-click={JS.toggle(to: "#theme-menu")}
        type="button"
      >
        <.theme_icon theme={@theme} />
      </button>

      <ul
        class="hidden absolute z-50 top-full right-0 mt-2 w-32 py-1 overflow-hidden rounded-lg shadow-lg text-sm font-semibold bg-white dark:bg-slate-800 focus:outline-none"
        id="theme-menu"
        role="listbox"
        tabindex="-1"
      >
        <%= for theme <- ~w(light dark system) do %>
          <.option value={theme} theme={@theme} />
        <% end %>
      </ul>
    </div>
    """
  end

  attr :theme, :string, required: true
  attr :value, :string, required: true

  defp option(assigns) do
    class =
      if assigns.theme == assigns.value do
        "text-blue-500 dark:text-blue-400"
      else
        "text-slate-500 dark:text-slate-400 "
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <li
      class={"block w-full py-1 px-2 flex items-center cursor-pointer space-x-2 hover:bg-slate-50 hover:dark:bg-slate-600/30 #{@class}"}
      id={"select-theme-#{@value}"}
      phx-click-away={JS.hide(to: "#theme-menu")}
      phx-hook="ChangeTheme"
      role="option"
      value={@value}
    >
      <.theme_icon theme={@value} />
      <span class="capitalize text-slate-800 dark:text-slate-200"><%= @value %></span>
    </li>
    """
  end

  attr :theme, :string, required: true

  defp theme_icon(assigns) do
    ~H"""
    <%= case @theme do %>
      <% "light" -> %>
        <Icons.sun />
      <% "dark" -> %>
        <Icons.moon />
      <% "system" -> %>
        <Icons.computer_desktop />
    <% end %>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("restore", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, theme)}
  end
end
