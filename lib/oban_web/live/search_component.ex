defmodule ObanWeb.SearchComponent do
  use ObanWeb.Web, :live_component

  def update(assigns, socket) do
    {:ok, assign(socket, show_clear?: present?(assigns.terms))}
  end

  def render(assigns) do
    ~L"""
    <form phx-target="<%= @myself %>" phx-change="search" phx-submit="search">
      <div class="relative w-96 rounded-md shadow-sm">
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400 pointer-events-none">
          <svg fill="currentColor" viewBox="0 0 20 20" class="h-5 w-5"><path d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
        </div>
        <input
          type="search"
          name="terms"
          class="appearance-none text-sm bg-gray-100 block rounded w-full pr-3 py-3 pl-10 placeholder-gray-600 focus:shadow-outline"
          placeholder="Search jobs by worker, tags and args"
          phx-debounce="250" />
        <button class="absolute inset-y-0 right-0 pr-3 <%= if @show_clear? do %>flex<% else %>hidden<% end %> items-center text-gray-400 hover:text-blue-500" phx-target="<%= @myself %>" phx-capture-click="clear">
          <svg fill="currentColor" viewBox="0 0 20 20" class="h-5 w-5"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
        </button>
      </div>
    </form>
    """
  end

  def handle_event("search", %{"terms" => terms}, socket) do
    send(self(), {:filter_terms, terms})

    {:noreply, socket}
  end

  def handle_event("clear", _params, socket) do
    send(self(), {:filter_terms, nil})

    {:noreply, socket}
  end

  def present?(nil), do: false
  def present?(""), do: false
  def present?(_), do: true
end
