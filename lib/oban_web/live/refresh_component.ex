defmodule ObanWeb.RefreshComponent do
  use ObanWeb.Web, :live_component

  @refresh_options [{"1s", 1}, {"2s", 2}, {"5s", 5}, {"15s", 15}, {"Off", -1}]

  def render(assigns) do
    ~L"""
    <form class="w-24 flex items-center" phx-change="select_refresh" phx-target="<%= @myself %>">
      <label for="refresh" class="block text-sm">Refresh</label>
      <div class="relative ml-2">
        <select name="refresh" class="block appearance-none bg-gray-50 border text-gray-700 px-3 py-2 pr-6 rounded leading-tight focus:outline-none focus:bg-white">
          <%= options_for_select(refresh_options(), @refresh) %>
        </select>
        <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-700">
          <svg class="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z"/></svg>
        </div>
      </div>
    </form>
    """
  end

  defp refresh_options, do: @refresh_options

  def handle_event("select_refresh", params, socket) do
    {refresh, ""} = Integer.parse(params["refresh"])

    send(self(), {:update_refresh, refresh})

    {:noreply, socket}
  end
end
