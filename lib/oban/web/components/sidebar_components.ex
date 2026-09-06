defmodule Oban.Web.SidebarComponents do
  use Oban.Web, :html

  alias Oban.Web.Colors

  # Header labels and row cells share these widths so the columns can't drift apart.
  @mode_class "w-12"
  @value_class "w-10"

  attr :csp_nonces, :map
  attr :width, :integer, default: 320
  slot :inner_block

  def sidebar(assigns) do
    ~H"""
    <style nonce={@csp_nonces.style}>
      #sidebar {
        width: var(--sidebar-width, <%= @width %>px);
      }
    </style>
    <div id="sidebar" class="relative flex-none mr-2 pr-3" phx-hook="SidebarResizer">
      {render_slot(@inner_block)}

      <div
        data-resize-handle
        role="separator"
        aria-orientation="vertical"
        aria-label="Resize sidebar"
        aria-valuemin="320"
        aria-valuemax="512"
        aria-valuenow={@width}
        tabindex="0"
        class="absolute top-0 right-0 bottom-0 w-1 cursor-col-resize group hover:bg-violet-500/30 focus-visible:outline-none focus-visible:bg-blue-500 transition-colors"
      >
        <div class="absolute top-8 right-0 w-1 h-12 bg-gray-300 dark:bg-gray-600 group-hover:bg-violet-500 rounded-full transition-colors">
        </div>
      </div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :headers, :list, required: true
  attr :mode_header, :string, default: nil
  slot :inner_block

  def section(assigns) do
    assigns = assign(assigns, mode_class: @mode_class, value_class: @value_class)

    ~H"""
    <div id={@name} class="w-full mb-3">
      <header class="flex items-center gap-1 py-3 pr-2">
        <button
          id={"#{@name}-toggle"}
          type="button"
          class="flex-none flex items-center justify-center w-6 h-6 rounded-md text-gray-400 hover:text-violet-500 dark:text-gray-500 dark:hover:text-violet-500 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
          aria-controls={"#{@name}-rows"}
          aria-expanded="true"
          aria-label={"Toggle #{@name}"}
          data-title={"Toggle #{@name}"}
          phx-click={toggle(@name)}
          phx-hook="Tippy"
        >
          <Icons.icon
            name="icon-chevron-right"
            id={"#{@name}-chevron"}
            class="w-4 h-4 transition-transform rotate-90"
          />
        </button>

        <h3 class="min-w-0 truncate font-semibold text-gray-900 dark:text-gray-200">
          {String.capitalize(@name)}
        </h3>

        <div class="ml-auto flex-none flex gap-1.5 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
          <span :if={@mode_header} class={@mode_class}>{@mode_header}</span>
          <span :for={header <- @headers} class={@value_class}>{header}</span>
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
  attr :exclusive, :boolean, default: false
  attr :state, :string, default: nil
  slot :statuses
  slot :leading

  def filter_row(assigns) do
    class =
      cond do
        assigns.exclusive and assigns.active ->
          "rounded-md bg-white hover:bg-white dark:bg-gray-800 dark:hover:bg-gray-800"

        assigns.exclusive ->
          "rounded-md hover:bg-gray-100 dark:hover:bg-gray-800"

        assigns.active ->
          "border-violet-500 hover:border-violet-500"

        true ->
          "hover:border-violet-400"
      end

    assigns =
      assign(assigns,
        class: class,
        dot_class: dot_class(assigns.state, List.first(assigns.values)),
        mode_class: @mode_class,
        value_class: @value_class
      )

    ~H"""
    <div class={["group flex items-center ml-2 my-0.5 pl-1 border-l-4 border-transparent", @class]}>
      <span class="flex-none w-4 flex items-center justify-center">
        <span :if={@state} aria-hidden="true" class={["w-2 h-2 rounded-full", @dot_class]} />
        {render_slot(@leading)}
      </span>

      <.link
        class={[
          "min-w-0 flex-1 flex items-center justify-between gap-1.5 pl-1 pr-2 py-2 rounded-md",
          "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-blue-500"
        ]}
        id={"filter-#{@name}"}
        aria-current={@active && "true"}
        patch={@patch}
        replace={true}
      >
        <span
          title={@name}
          class={[
            "min-w-0 text-sm text-gray-700 dark:text-gray-300 text-left tabular font-medium truncate",
            if(@active, do: "font-semibold")
          ]}
        >
          {String.downcase(@name)}
        </span>

        <div class="flex-none flex items-center gap-1.5">
          <div
            :if={@statuses != []}
            class={[
              @mode_class,
              "flex items-center justify-end gap-1 text-gray-400 dark:text-gray-500"
            ]}
          >
            {render_slot(@statuses)}
          </div>

          <span
            :for={value <- @values}
            class={[@value_class, "block text-sm text-right tabular", value_class(value)]}
          >
            {integer_to_estimate(value)}
          </span>
        </div>
      </.link>
    </div>
    """
  end

  defp dot_class(state, value) when is_binary(state) and is_integer(value) and value > 0 do
    Colors.state_bg_class(state)
  end

  defp dot_class(_state, _value), do: "bg-gray-300 dark:bg-gray-600"

  defp value_class(value) when is_integer(value) and value > 0 do
    "text-gray-600 dark:text-gray-400"
  end

  defp value_class(_value), do: "text-gray-500 dark:text-gray-500"

  defp toggle(prefix) do
    %JS{}
    |> JS.toggle(in: "fade-in-scale", out: "fade-out-scale", to: "##{prefix}-rows")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "##{prefix}-toggle")
    |> JS.add_class("rotate-90", to: "##{prefix}-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "##{prefix}-chevron.rotate-90")
  end
end
