defmodule ObanWeb.ListingComponent do
  use ObanWeb.Web, :live_component

  alias ObanWeb.ListingRowComponent

  def render(assigns) do
    ~L"""
    <div>
      <div class="flex justify-between border-b border-gray-200 px-3 py-3">
        <span class="text-xs text-gray-400 pl-8 uppercase">Worker</span>

        <div class="flex justify-end">
          <span class="flex-none w-24 text-xs text-right text-gray-400 pl-3 uppercase">Queue</span>
          <span class="flex-none w-20 text-xs text-right text-gray-400 pl-3 uppercase">Atmpt</span>
          <span class="flex-none w-20 text-xs text-right text-gray-400 pl-3 mr-16 uppercase">Time</span>
        </div>
      </div>
      <ul>
        <%= for job <- @jobs do %>
          <%= live_component @socket, ListingRowComponent, id: job.id, job: job %>
        <% end %>
      </ul>
    </div>
    """
  end
end
