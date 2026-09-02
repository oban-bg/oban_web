defmodule Oban.Web.HelpComponent do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="help-selector">
      <Core.dropdown_menu
        id="help"
        title="Help"
        aria_label="Help"
        menu_class="w-48 overflow-hidden"
        toggle_class="hidden sm:flex h-9 w-9 items-center justify-center text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 hover:bg-black/5 dark:hover:bg-white/5"
      >
        <:toggle>
          <Icons.icon name="icon-question-mark-circle" />
        </:toggle>

        <Core.menu_option
          class="text-gray-500 dark:text-gray-400"
          href="https://hexdocs.pm/oban_web"
          target="_blank"
          rel="noopener noreferrer"
          phx-click={Core.close_menu("help")}
        >
          <Icons.icon name="icon-arrow-top-right-on-square" class="w-5 h-5" />
          <span class="text-gray-800 dark:text-gray-200">Documentation</span>
        </Core.menu_option>

        <Core.menu_option
          class="text-gray-500 dark:text-gray-400"
          phx-click={Core.close_menu("help") |> JS.exec("data-shortcut", to: "#shortcuts")}
        >
          <Icons.icon name="icon-command-line" class="w-5 h-5" />
          <span class="text-gray-800 dark:text-gray-200">Keyboard shortcuts</span>
        </Core.menu_option>
      </Core.dropdown_menu>
    </div>
    """
  end
end
