defmodule ObanWeb.SearchComponent do
  use ObanWeb.Web, :live_component

  def render(assigns) do
    ~L"""
    <form phx-target="<%= @myself %>" phx-change="search" phx-submit="search">
      <div class="relative w-96 rounded-md shadow-sm">
        <div class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-500 pointer-events-none">
          <svg fill="currentColor" viewBox="0 0 20 20" class="h-5 w-5"><path d="M8 4a4 4 0 100 8 4 4 0 000-8zM2 8a6 6 0 1110.89 3.476l4.817 4.817a1 1 0 01-1.414 1.414l-4.816-4.816A6 6 0 012 8z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
        </div>
        <input
          type="search"
          name="terms"
          class="appearance-none bg-gray-100 block rounded w-full pr-3 py-3 pl-10 placeholder-gray-500 focus:shadow-outline"
          placeholder="Search jobs by worker, tags and args"
          phx-debounce="250" />
      </div>
    </form>
    """
  end

  def handle_event("search", %{"terms" => terms}, socket) do
    send(self(), {:filter_terms, terms})

    {:noreply, socket}
  end
end
