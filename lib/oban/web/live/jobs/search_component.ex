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

      <div class="relative w-96 rounded-md shadow-sm">
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400 pointer-events-none">
          <Icons.magnifying_glass class="w-5 h-5" />
        </div>
        <input
          type="search"
          name="terms"
          class="appearance-none text-sm border-gray-300 dark:border-gray-500 bg-gray-100 dark:bg-gray-800 block rounded-md w-full pr-3 py-2.5 pl-10 placeholder-gray-600 dark:placeholder-gray-400 focus:outline-none focus:ring-blue-400 focus:border-blue-400"
          placeholder="Search"
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
