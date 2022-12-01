defmodule Oban.Web.Components.Theme do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, :theme, "unknown")}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="ml-3 relative" id="theme-selector" phx-hook="RestoreTheme">
      <button
        id="dark-toggle"
        class="text-slate-500 dark:text-slate-400 focus:outline-none hover:text-slate-600 dark:hover:text-slate-300 hidden md:block"
        aria-haspopup="listbox"
        aria-expanded="true"
        aria-labelledby="listbox-label"
        data-title="Toggle theme"
        phx-hook="Tippy"
        phx-click={JS.toggle(to: "#theme-menu")}
        type="button"
      >
        <%= case @theme do %>
          <% "light" -> %>
            <Icons.sun />
          <% "dark" -> %>
            <Icons.moon />
          <% "system" -> %>
            <Icons.computer_desktop />
          <% _ -> %>
            <span class="block w-6 h-6"></span>
        <% end %>
      </button>

      <ul
        id="theme-menu"
        class="hidden absolute z-50 top-full right-0 mt-4 overflow-hidden rounded-lg shadow-lg w-36 py-1 text-sm font-semibold bg-white dark:bg-slate-800"
        tabindex="-1"
        role="listbox"
      >
        <.option value="light" current={@theme}>
          <Icons.sun />
        </.option>

        <.option value="dark" current={@theme}>
          <Icons.moon />
        </.option>

        <.option value="system" current={@theme}>
          <Icons.computer_desktop />
        </.option>
      </ul>
    </div>
    """
  end

  attr :current, :string, required: true
  attr :value, :string, required: true
  slot :inner_block, required: true

  defp option(assigns) do
    class =
      if assigns.current == assigns.value do
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
      <%= render_slot(@inner_block) %>
      <span class="capitalize text-slate-800 dark:text-slate-200"><%= @value %></span>
    </li>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("restore", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, theme)}
  end
end
