defmodule Oban.Web.SidebarComponents do
  use Oban.Web, :html

  def sidebar(assigns) do
    ~H"""
    <div id="sidebar" class="mr-3">{render_slot(@inner_block)}</div>
    """
  end

  attr :name, :string, required: true
  attr :headers, :list, required: true
  slot :inner_block

  def section(assigns) do
    ~H"""
    <div id={@name} class="bg-transparent dark:bg-transparent w-fill mb-3 overflow-hidden md:w-84">
      <header class="flex justify-between items-center border-b border-gray-300 dark:border-gray-700 py-3">
        <button
          id={"#{@name}-toggle"}
          class="text-gray-400 hover:text-violet-500 dark:text-gray-600 dark:hover:text-violet-500"
          data-title={"Toggle #{@name}"}
          phx-click={toggle(@name)}
          phx-hook="Tippy"
        >
          <Icons.chevron_right class="w-5 h-5 mr-2 transition-transform rotate-90" />
        </button>

        <h3 class="dark:text-gray-200 font-bold">{String.capitalize(@name)}</h3>

        <div class="ml-auto flex space-x-3 text-xs text-gray-600 dark:text-gray-400 uppercase text-right">
          <span :for={header <- @headers} class="w-12">{header}</span>
        </div>
      </header>

      <div id={"#{@name}-rows"}>{render_slot(@inner_block)}</div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :values, :list, required: true
  attr :patch, :any, required: true
  attr :active, :boolean, default: false

  def filter_row(assigns) do
    ~H"""
    <.link
      patch={@patch}
      replace={true}
      class={[
        "flex justify-between pr-2 py-2 my-0.5 border-l-4 border-transparent
        hover:border-violet-400 focus:border-violet-200",
        if(@active, do: "border-violet-500 hover:border-violet-500 focus:border-violet-500")
      ]}
    >
      <span class="pl-2 text-sm text-gray-700 dark:text-gray-300 text-left tabular font-medium truncate">
        {String.downcase(@name)}
      </span>

      <div class="flex-none flex items-center space-x-3">
        <span
          :for={value <- @values}
          class="block w-12 text-sm text-right tabular text-gray-600 dark:text-gray-400"
        >
          {integer_to_estimate(value)}
        </span>
      </div>
    </.link>
    """
  end

  defp toggle(prefix) do
    %JS{}
    |> JS.toggle(in: "fade-in-scale", out: "fade-out-scale", to: "##{prefix}-rows")
    |> JS.add_class("rotate-90", to: "##{prefix}-toggle svg:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "##{prefix}-toggle svg.rotate-90")
  end
end
