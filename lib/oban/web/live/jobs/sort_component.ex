defmodule Oban.Web.Jobs.SortComponent do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="job-sort" class="w-28 relative">
      <button
        aria-expanded="true"
        aria-haspopup="listbox"
        class="w-full flex justify-left items-center cursor-pointer rounded-md bg-white
        dark:bg-gray-900 py-2.5 px-3 text-sm text-gray-500 dark:text-gray-400 hover:text-gray-800
        dark:hover:text-gray-200 ring-1 ring-inset ring-gray-300 dark:ring-gray-700 focus:outline-none focus:ring-blue-500"
        data-title="Change sort order"
        id="sort-menu-button"
        phx-click={JS.toggle(to: "#sort-menu")}
        phx-hook="Tippy"
        type="button"
      >
        <%= if @params.sort_dir == "asc" do %>
          <Icons.bars_arrow_down class="w-4 h-4" />
        <% else %>
          <Icons.bars_arrow_up class="w-4 h-4" />
        <% end %>
        <span class="ml-1 block capitalize">{@params.sort_by}</span>
      </button>

      <nav
        class="hidden absolute z-10 mt-1 w-full text-sm font-semibold overflow-auto rounded-md bg-white
        dark:bg-gray-800 shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm"
        id="sort-menu"
        role="listbox"
        tabindex="-1"
      >
        <.option
          :for={value <- ["time", "attempt", "queue", "worker"]}
          link={oban_path(:jobs, Map.put(@params, :sort_by, value))}
          selected={@params.sort_by}
          value={value}
        />
        <hr class="w-full border-0 border-b border-gray-200 dark:border-gray-700 my-2" />
        <.option
          :for={value <- ~w(asc desc)}
          link={oban_path(:jobs, Map.put(@params, :sort_dir, value))}
          selected={@params.sort_dir}
          value={value}
        />
      </nav>
    </div>
    """
  end

  defp option(assigns) do
    ~H"""
    <.link
      class="block w-full flex items-center py-1 px-2 cursor-pointer select-none space-x-2 hover:bg-gray-50 hover:dark:bg-gray-600/30"
      id={"sort-#{@value}"}
      patch={@link}
      phx-click-away={JS.hide(to: "#sort-menu")}
      phx-click={JS.hide(to: "#sort-menu")}
      role="option"
    >
      <%= if @value == @selected do %>
        <Icons.check class="w-4 h-4 text-blue-500" />
      <% else %>
        <span class="block w-4 h-4"></span>
      <% end %>
      <span class="capitalize text-gray-800 dark:text-gray-200">
        {String.replace(@value, "_", " ")}
      </span>
    </.link>
    """
  end
end
