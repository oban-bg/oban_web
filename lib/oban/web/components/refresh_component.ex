defmodule Oban.Web.RefreshComponent do
  use Oban.Web, :live_component

  @refresh_options [{"1s", 1}, {"2s", 2}, {"5s", 5}, {"15s", 15}, {"Off", -1}]

  def render(assigns) do
    ~L"""
    <form class="flex items-center ml-auto" phx-change="select_refresh" phx-target="<%= @myself %>">
      <label for="refresh" class="block text-sm text-gray-700 dark:text-gray-400">Refresh</label>
      <div class="relative ml-2">
        <select id="refresh" name="refresh" class="block border-gray-300 dark:border-gray-500 bg-gray-50 dark:bg-gray-700 text-gray-700 dark:text-gray-200 px-3 py-2 pr-6 rounded-md focus:outline-none focus:ring-blue-400 focus:border-blue-400">
          <%= options_for_select(refresh_options(), @refresh) %>
        </select>
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
