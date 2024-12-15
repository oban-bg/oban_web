defmodule Oban.Web.Live.Theme do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      class="relative"
      id="theme-selector"
      data-shortcut={JS.push("cycle-theme", target: "#theme-selector")}
      phx-hook="Themer"
    >
      <button
        aria-expanded="true"
        aria-haspopup="listbox"
        class="text-gray-500 dark:text-gray-400 focus:outline-none hover:text-gray-600 dark:hover:text-gray-200 hidden md:block"
        data-title="Change theme"
        id="theme-menu-toggle"
        phx-hook="Tippy"
        phx-click={JS.toggle(to: "#theme-menu")}
        type="button"
      >
        <.theme_icon theme={@theme} />
      </button>

      <ul
        class="hidden absolute z-50 top-full right-0 mt-2 w-32 overflow-hidden rounded-md shadow-lg text-sm font-semibold bg-white dark:bg-gray-800 focus:outline-none"
        id="theme-menu"
        role="listbox"
        tabindex="-1"
      >
        <.option :for={theme <- ~w(light dark system)} myself={@myself} theme={@theme} value={theme} />
      </ul>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :theme, :string, required: true
  attr :value, :string, required: true

  defp option(assigns) do
    class =
      if assigns.theme == assigns.value do
        "text-blue-500 dark:text-blue-400"
      else
        "text-gray-500 dark:text-gray-400 "
      end

    assigns = assign(assigns, :class, class)

    ~H"""
    <li
      class={"block w-full py-1 px-2 flex items-center cursor-pointer space-x-2 hover:bg-gray-50 hover:dark:bg-gray-600/30 #{@class}"}
      id={"select-theme-#{@value}"}
      phx-click-away={JS.hide(to: "#theme-menu")}
      phx-click="update-theme"
      phx-target={@myself}
      phx-value-theme={@value}
      role="option"
    >
      <.theme_icon theme={@value} />
      <span class="capitalize text-gray-800 dark:text-gray-200">{@value}</span>
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
  def handle_event("update-theme", %{"theme" => theme}, socket) do
    send(self(), {:update_theme, theme})

    {:noreply, socket}
  end

  def handle_event("cycle-theme", _params, socket) do
    theme =
      case socket.assigns.theme do
        "light" -> "dark"
        "dark" -> "system"
        "system" -> "light"
      end

    send(self(), {:update_theme, theme})

    {:noreply, socket}
  end
end
