defmodule Oban.Web.RefreshComponent do
  use Oban.Web, :live_component

  @options [
    {01, "1s"},
    {02, "2s"},
    {05, "5s"},
    {15, "15s"},
    {30, "30s"},
    {60, "1m"},
    {-1, "Off"}
  ]

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, :options, @options)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id="refresh-selector"
      data-shortcut={JS.push("toggle-refresh", target: "#refresh-selector")}
      phx-hook="Refresher"
    >
      <Core.dropdown_menu
        id="refresh"
        title="Change refresh rate"
        aria_label="Change refresh rate"
        menu_class="w-18 overflow-hidden"
        toggle_class="hidden sm:flex h-9 px-2.5 items-center text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200 hover:bg-black/5 dark:hover:bg-white/5"
      >
        <:toggle>
          <Icons.icon name="icon-arrow-path-rounded" />
          <span class="ml-1 leading-6 text-sm">{interval_label(@refresh, @options)}</span>
        </:toggle>

        <%= for {value, display} <- @options do %>
          <.option value={value} display={display} refresh={@refresh} />
        <% end %>
      </Core.dropdown_menu>
    </div>
    """
  end

  defp interval_label(refresh, options) do
    case List.keyfind(options, refresh, 0) do
      {_interval, display} -> display
      nil -> "#{refresh}s"
    end
  end

  attr :refresh, :integer, required: true
  attr :value, :integer, required: true
  attr :display, :string, required: true

  defp option(assigns) do
    {class, label_class} =
      if assigns.refresh == assigns.value do
        {"text-blue-500 dark:text-blue-400", "text-blue-500 dark:text-blue-400"}
      else
        {"text-gray-500 dark:text-gray-400", "text-gray-800 dark:text-gray-200"}
      end

    assigns = assign(assigns, class: class, label_class: label_class)

    ~H"""
    <Core.menu_option
      class={["select-none", @class]}
      selected={@value == @refresh}
      phx-click={
        "select-refresh"
        |> JS.push(target: "#refresh-selector")
        |> Core.close_menu("refresh")
        |> JS.focus(to: "#refresh-menu-toggle")
      }
      phx-value-interval={@value}
    >
      <%= if @value == @refresh do %>
        <Icons.icon name="icon-check" class="w-5 h-5" />
      <% else %>
        <span class="block w-5 h-5"></span>
      <% end %>

      <span class={@label_class}>{@display}</span>
    </Core.menu_option>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("pause-refresh", _params, socket) do
    send(self(), :pause_refresh)

    {:noreply, socket}
  end

  def handle_event("resume-refresh", _params, socket) do
    send(self(), :resume_refresh)

    {:noreply, socket}
  end

  def handle_event("select-refresh", %{"interval" => interval}, socket) do
    value = if is_binary(interval), do: String.to_integer(interval), else: interval

    send(self(), {:update_refresh, value})

    {:noreply, socket}
  end

  def handle_event("toggle-refresh", _params, socket) do
    send(self(), :toggle_refresh)

    {:noreply, socket}
  end
end
