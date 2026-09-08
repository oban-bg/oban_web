defmodule Oban.Web.SortComponent do
  use Oban.Web, :html

  attr :id, :string, default: "job-sort"
  attr :by, :list, required: true
  attr :defaults, :map, default: %{}
  attr :page, :atom, default: :jobs
  attr :params, :map, required: true

  def select(assigns) do
    # Sorting layers on top of whatever is filtered, so the links keep the filters while
    # dropping any defaults that would otherwise leak into the URL.
    params =
      assigns.params
      |> without_defaults(assigns.defaults)
      |> Map.merge(Map.take(assigns.params, [:sort_by, :sort_dir]))

    assigns = assign(assigns, params: params, flipped: flip(params.sort_dir))

    ~H"""
    <div
      id={@id}
      class="h-10 flex items-stretch rounded-md bg-white dark:bg-gray-900 ring-1 ring-inset ring-gray-300 dark:ring-gray-700 text-sm text-gray-500 dark:text-gray-400"
    >
      <Core.dropdown_menu
        id={"#{@id}-by"}
        aria_label={"Sort by #{label(@params.sort_by)}"}
        menu_class="w-40 overflow-hidden"
        title="Sort by"
        toggle_class="h-full w-32 pl-3 pr-2 flex items-center justify-between rounded-r-none hover:text-gray-800 dark:hover:text-gray-200"
      >
        <:toggle>
          <span class="truncate">{label(@params.sort_by)}</span>
          <Icons.icon name="icon-chevron-down" class="w-4 h-4 shrink-0" />
        </:toggle>

        <Core.menu_option
          :for={value <- @by}
          id={"sort-#{value}"}
          selected={value == @params.sort_by}
          phx-click={
            @page
            |> oban_path(Map.put(@params, :sort_by, value))
            |> JS.patch()
            |> Core.close_menu("#{@id}-by")
            |> JS.focus(to: "##{@id}-by-menu-toggle")
          }
        >
          <%= if value == @params.sort_by do %>
            <Icons.icon name="icon-check" class="w-4 h-4 shrink-0 text-blue-500" />
          <% else %>
            <span class="block w-4 h-4 shrink-0"></span>
          <% end %>
          <span class="text-gray-800 dark:text-gray-200">{label(value)}</span>
        </Core.menu_option>
      </Core.dropdown_menu>

      <.link
        aria-label={"Sorted #{direction(@params.sort_dir)}, switch to #{direction(@flipped)}"}
        class="px-2 flex items-center rounded-r-md border-l border-gray-300 dark:border-gray-700 hover:text-gray-800 dark:hover:text-gray-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-blue-500"
        data-title={"Switch to #{direction(@flipped)}"}
        id={"#{@id}-dir"}
        patch={oban_path(@page, Map.put(@params, :sort_dir, @flipped))}
        phx-hook="Tippy"
      >
        <%= if @params.sort_dir == "asc" do %>
          <Icons.icon name="icon-bars-arrow-down" class="w-5 h-5" />
        <% else %>
          <Icons.icon name="icon-bars-arrow-up" class="w-5 h-5" />
        <% end %>
      </.link>
    </div>
    """
  end

  defp flip("asc"), do: "desc"
  defp flip("desc"), do: "asc"

  defp direction("asc"), do: "ascending"
  defp direction("desc"), do: "descending"

  # Sort keys are abbreviated in the URL, but the menu spells them out the way the columns do.
  defp label("avail"), do: "Available"
  defp label("sched"), do: "Scheduled"
  defp label("retry"), do: "Retryable"
  defp label("exec"), do: "Executing"
  defp label("local"), do: "Local limit"
  defp label("global"), do: "Global limit"
  defp label(value), do: value |> String.replace("_", " ") |> String.capitalize()
end
