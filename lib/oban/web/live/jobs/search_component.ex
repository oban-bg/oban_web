defmodule Oban.Web.Jobs.SearchComponent do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    terms = assigns.params[:terms]

    {:ok, assign(socket, params: assigns.params, show_clear?: present?(terms), terms: terms)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    clear_class = if assigns.show_clear?, do: "flex", else: "hidden"

    assigns = assign(assigns, clear_class: clear_class)

    ~H"""
    <form
      id="search"
      phx-change="search"
      phx-submit="search"
      phx-target={@myself}
    >
      <div phx-key="/" phx-window-keydown={JS.focus_first(to: "#search")}></div>

      <div class="relative w-96">
        <div class="absolute inset-y-0 left-0 pl-1.5 flex items-center text-gray-500 pointer-events-none">
          <Icons.magnifying_glass class="w-5 h-5" />
        </div>
        <input
          type="search"
          name="terms"
          class="appearance-none text-sm border-none block rounded-md shadow-inner w-full pr-3 py-2.5 pl-8 ring-1 ring-inset ring-gray-300 placeholder-gray-400 dark:placeholder-gray-600 focus:outline-none focus:ring-blue-500 focus:bg-blue-100/10"
          placeholder="Search..."
          value={@terms}
          phx-debounce="1000"
        />
        <button
          class={"absolute inset-y-0 right-0 pr-3 items-center text-gray-400 hover:text-blue-500 #{@clear_class}"}
          type="reset"
          phx-target={@myself}
          phx-click="clear"
        >
          <Icons.x_circle class="w-5 h-5" />
        </button>
      </div>
    </form>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("search", %{"terms" => terms}, socket) do
    send(self(), {:params, :terms, terms})

    {:noreply, socket}
  end

  def handle_event("clear", _params, socket) do
    send(self(), {:params, :terms, nil})

    {:noreply, socket}
  end

  def present?(nil), do: false
  def present?(""), do: false
  def present?(_), do: true
end
