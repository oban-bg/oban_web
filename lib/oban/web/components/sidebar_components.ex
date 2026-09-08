defmodule Oban.Web.SidebarComponents do
  use Oban.Web, :html

  alias Oban.Web.Colors

  # Header labels and row cells share these widths so the columns can't drift apart.
  @mode_class "w-12"
  @value_class "w-10"

  attr :csp_nonces, :map
  attr :label, :string, default: "Filters"
  attr :width, :integer, default: 320
  slot :inner_block

  def sidebar(assigns) do
    ~H"""
    <style nonce={@csp_nonces.style}>
      #sidebar {
        width: var(--sidebar-width, <%= @width %>px);
      }
    </style>
    <aside
      id="sidebar"
      aria-label={@label}
      class="relative flex-none mr-2 pr-3"
      phx-hook="SidebarResizer"
    >
      {render_slot(@inner_block)}

      <div
        data-resize-handle
        role="separator"
        aria-orientation="vertical"
        aria-label="Resize sidebar"
        aria-valuemin="320"
        aria-valuemax="512"
        aria-valuenow={@width}
        aria-valuetext={"#{@width} pixels"}
        tabindex="0"
        class="absolute top-0 right-0 bottom-0 w-1 cursor-col-resize group hover:bg-violet-500/30 focus-visible:outline-none focus-visible:bg-blue-500 transition-colors"
      >
        <div class="absolute top-8 right-0 w-1 h-12 bg-gray-300 dark:bg-gray-600 group-hover:bg-violet-500 rounded-full transition-colors">
        </div>
      </div>
    </aside>
    """
  end

  attr :name, :string, required: true
  attr :headers, :list, required: true
  attr :mode_header, :map, default: nil
  attr :expanded, :boolean, default: true
  slot :inner_block

  def section(assigns) do
    assigns =
      assign(assigns,
        headers: Enum.map(assigns.headers, &normalize_header/1),
        labels: Enum.map(assigns.headers, &header_label/1),
        mode_class: @mode_class,
        value_class: @value_class,
        verb: if(assigns.expanded, do: "Collapse", else: "Expand")
      )

    ~H"""
    <div id={@name} class="w-full mb-3">
      <header class="flex items-center gap-1 py-3 pr-2">
        <button
          id={"#{@name}-toggle"}
          type="button"
          class="flex-none flex items-center justify-center w-6 h-6 rounded-md cursor-pointer text-gray-400 hover:text-violet-500 dark:text-gray-500 dark:hover:text-violet-500 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
          aria-controls={"#{@name}-rows"}
          aria-expanded={to_string(@expanded)}
          aria-label={"#{@verb} #{@name}"}
          data-title={"#{@verb} #{@name}"}
          phx-click={toggle(@name)}
          phx-hook="Tippy"
        >
          <Icons.icon
            name="icon-chevron-right"
            id={"#{@name}-chevron"}
            class={["w-4 h-4 transition-transform", @expanded && "rotate-90"]}
          />
        </button>

        <h3 class="min-w-0 truncate font-semibold text-gray-900 dark:text-gray-200">
          {String.capitalize(@name)}
        </h3>

        <div class="ml-auto flex-none flex gap-1.5 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
          <.header_cell
            :if={@mode_header}
            id={"#{@name}-header-mode"}
            header={@mode_header}
            class={@mode_class}
          />
          <.header_cell
            :for={{header, index} <- Enum.with_index(@headers)}
            id={"#{@name}-header-#{index}"}
            header={header}
            class={@value_class}
          />
        </div>
      </header>

      <div id={"#{@name}-rows"} class={[not @expanded && "hidden"]}>
        {render_slot(@inner_block, @labels)}
      </div>
    </div>
    """
  end

  # A header is a map with a `:label` used for screen readers and tooltips. A `:short` key renders
  # an abbreviation in place of the label, and a `:state` key renders that state's dot instead.
  defp normalize_header(header) when is_binary(header), do: %{label: header}
  defp normalize_header(header) when is_map(header), do: header

  defp header_label(header) when is_binary(header), do: header
  defp header_label(%{label: label}), do: label

  attr :id, :string, required: true
  attr :header, :map, required: true
  attr :class, :string, required: true

  defp header_cell(%{header: %{state: state}} = assigns) do
    assigns = assign(assigns, dot_class: Colors.state_bg_class(state))

    ~H"""
    <span
      id={@id}
      class={[@class, "flex items-center justify-end"]}
      data-title={@header.label}
      phx-hook="Tippy"
    >
      <span aria-hidden="true" class={["w-2 h-2 rounded-full", @dot_class]} />
      <span class="sr-only">{@header.label}</span>
    </span>
    """
  end

  defp header_cell(%{header: %{short: short, label: label}} = assigns) when short != label do
    ~H"""
    <span id={@id} class={[@class, "block"]} data-title={@header.label} phx-hook="Tippy">
      <span aria-hidden="true">{@header.short}</span>
      <span class="sr-only">{@header.label}</span>
    </span>
    """
  end

  defp header_cell(assigns) do
    ~H"""
    <span id={@id} class={[@class, "block"]}>{@header.label}</span>
    """
  end

  attr :name, :string, required: true
  attr :values, :list, required: true
  attr :patch, :any, required: true
  attr :labels, :list, default: []
  attr :active, :boolean, default: false
  attr :exclusive, :boolean, default: false
  attr :state, :string, default: nil
  attr :tooltip, :string, default: nil
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

    labels = assigns.labels ++ List.duplicate(nil, length(assigns.values))

    assigns =
      assign(assigns,
        class: class,
        cells: Enum.zip(assigns.values, labels),
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
        :if={@exclusive}
        class={[
          "min-w-0 flex-1 flex items-center justify-between gap-1.5 pl-1 pr-2 py-2 rounded-md",
          "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-blue-500"
        ]}
        id={"filter-#{@name}"}
        aria-current={@active && "true"}
        patch={@patch}
        replace={true}
      >
        <.row_name name={@name} active={@active} />
        <.row_values cells={@cells} />
      </.link>

      <button
        :if={not @exclusive}
        type="button"
        class={[
          "min-w-0 flex-1 flex items-center justify-between gap-1.5 pl-1 pr-2 py-2 rounded-md cursor-pointer",
          "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-blue-500"
        ]}
        id={"filter-#{@name}"}
        aria-pressed={to_string(@active)}
        data-title={@tooltip}
        phx-click={JS.patch(@patch, replace: true)}
        phx-hook={if @tooltip, do: "Tippy"}
      >
        <.row_name name={@name} active={@active} title={is_nil(@tooltip)} />

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

          <.row_values cells={@cells} />
        </div>
      </button>
    </div>
    """
  end

  attr :text, :string, required: true

  def empty_row(assigns) do
    ~H"""
    <p class="ml-2 pl-7 py-2 text-sm text-gray-400 dark:text-gray-500">{@text}</p>
    """
  end

  attr :name, :string, required: true
  attr :active, :boolean, required: true
  attr :title, :boolean, default: true

  defp row_name(assigns) do
    ~H"""
    <span
      title={@title && @name}
      class={[
        "min-w-0 text-sm text-gray-700 dark:text-gray-300 text-left font-medium truncate",
        if(@active, do: "font-semibold")
      ]}
    >
      {String.downcase(@name)}
    </span>
    """
  end

  attr :cells, :list, required: true

  defp row_values(assigns) do
    assigns = assign(assigns, value_class: @value_class)

    ~H"""
    <span
      :for={{value, label} <- @cells}
      class={[@value_class, "block text-sm text-right tabular", value_class(value)]}
    >
      <span :if={label} class="sr-only">{label}</span>
      {integer_to_estimate(value)}
    </span>
    """
  end

  defp dot_class(state, value) when is_binary(state) and is_integer(value) and value > 0 do
    Colors.state_bg_class(state)
  end

  defp dot_class(state, nil) when is_binary(state), do: Colors.state_bg_class(state)
  defp dot_class(_state, _value), do: "bg-gray-300 dark:bg-gray-600"

  defp value_class(value) when is_integer(value) and value > 0 do
    "text-gray-600 dark:text-gray-400"
  end

  defp value_class(_value), do: "text-gray-400 dark:text-gray-600"

  # Toggling happens on the client for an immediate, animated response, then the server learns the
  # new state so that it survives re-renders and is stored for the next visit.
  defp toggle(name) do
    %JS{}
    |> JS.toggle(in: "fade-in-scale", out: "fade-out-scale", to: "##{name}-rows")
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "##{name}-toggle")
    |> JS.add_class("rotate-90", to: "##{name}-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "##{name}-chevron.rotate-90")
    |> JS.push("toggle-section", value: %{name: name})
  end
end
