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
          <span class="flex-none w-20 text-xs text-right text-gray-400 pl-3 mr-8 uppercase">Time</span>
        </div>
      </div>

      <%= if Enum.empty?(@jobs) do %>
        <div class="flex justify-center py-20">
          <span class="text-lg text-gray-500 ml-3">No jobs match the current set of filters.</span>
        </div>
      <% end %>

      <ul>
        <%= for job <- @jobs do %>
          <%= live_component @socket, ListingRowComponent, id: job.id, job: job, selected: @selected %>
        <% end %>
      </ul>
    </div>
    """
  end
end
