defmodule Oban.Web.HelpComponent do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="relative" id="help-selector">
      <button
        aria-expanded="true"
        aria-haspopup="listbox"
        class="cursor-pointer text-gray-500 dark:text-gray-400 focus:outline-none hover:text-gray-700 dark:hover:text-gray-200 hidden md:block"
        data-title="Help"
        id="help-menu-toggle"
        phx-hook="Tippy"
        phx-click={JS.toggle(to: "#help-menu")}
        type="button"
      >
        <Icons.question_mark_circle />
      </button>

      <ul
        class="hidden absolute z-50 top-full right-0 mt-2 py-2 w-48 overflow-hidden rounded-md shadow-lg text-sm font-semibold bg-white dark:bg-gray-800 focus:outline-none"
        id="help-menu"
        role="listbox"
        tabindex="-1"
      >
        <li
          class="block w-full py-1 px-2 flex items-center cursor-pointer space-x-2 text-gray-500 dark:text-gray-400 hover:bg-gray-50 hover:dark:bg-gray-600/30"
          phx-click-away={JS.hide(to: "#help-menu")}
          role="option"
        >
          <a
            href="https://hexdocs.pm/oban_web"
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center space-x-2 w-full"
          >
            <Icons.arrow_top_right_on_square class="w-5 h-5" />
            <span class="text-gray-800 dark:text-gray-200">Documentation</span>
          </a>
        </li>
        <li
          class="block w-full py-1 px-2 flex items-center cursor-pointer space-x-2 text-gray-500 dark:text-gray-400 hover:bg-gray-50 hover:dark:bg-gray-600/30"
          phx-click-away={JS.hide(to: "#help-menu")}
          phx-click={JS.hide(to: "#help-menu") |> JS.exec("data-shortcut", to: "#shortcuts")}
          role="option"
        >
          <Icons.command_line class="w-5 h-5" />
          <span class="text-gray-800 dark:text-gray-200">Keyboard shortcuts</span>
        </li>
      </ul>
    </div>
    """
  end
end
