defmodule Oban.Web.ThemeComponent do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id="theme-selector"
      data-shortcut={JS.push("cycle-theme", target: "#theme-selector")}
      phx-hook="Themer"
    >
      <Core.dropdown_menu
        id="theme"
        title="Change theme"
        aria_label="Change theme"
        toggle_class="hidden sm:flex h-9 w-9 items-center justify-center text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 hover:bg-black/5 dark:hover:bg-white/5"
      >
        <:toggle>
          <.theme_icon theme={@theme} />
        </:toggle>

        <.option :for={theme <- ~w(light dark system)} myself={@myself} theme={@theme} value={theme} />
      </Core.dropdown_menu>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :theme, :string, required: true
  attr :value, :string, required: true

  defp option(assigns) do
    {class, label_class} =
      if assigns.theme == assigns.value do
        {"text-blue-500 dark:text-blue-400", "text-blue-500 dark:text-blue-400"}
      else
        {"text-gray-500 dark:text-gray-400", "text-gray-800 dark:text-gray-200"}
      end

    assigns = assign(assigns, class: class, label_class: label_class)

    ~H"""
    <Core.menu_option
      class={@class}
      id={"select-theme-#{@value}"}
      selected={@theme == @value}
      phx-click={
        "update-theme"
        |> JS.push(target: @myself)
        |> Core.close_menu("theme")
        |> JS.focus(to: "#theme-menu-toggle")
      }
      phx-value-theme={@value}
    >
      <.theme_icon theme={@value} />
      <span class={["capitalize", @label_class]}>{@value}</span>
    </Core.menu_option>
    """
  end

  attr :theme, :string, required: true

  defp theme_icon(assigns) do
    ~H"""
    <%= case @theme do %>
      <% "light" -> %>
        <Icons.icon name="icon-sun" />
      <% "dark" -> %>
        <Icons.icon name="icon-moon" />
      <% "system" -> %>
        <Icons.icon name="icon-computer-desktop" />
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
