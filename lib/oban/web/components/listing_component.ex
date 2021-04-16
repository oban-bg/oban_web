defmodule Oban.Web.ListingComponent do
  use Oban.Web, :live_component

  alias Oban.Web.ListingRowComponent

  @inc_limit 20
  @max_limit 200
  @min_limit 20

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       jobs: assigns.jobs,
       selected: assigns.selected,
       show_less?: assigns.params.limit > @min_limit,
       show_more?: assigns.params.limit < @max_limit
     )}
  end

  def render(assigns) do
    ~L"""
    <div id="listing">
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
      <% else %>
        <ul>
          <%= for job <- @jobs do %>
            <%= live_component @socket, ListingRowComponent, id: job.id, job: job, selected: @selected %>
          <% end %>
        </ul>

        <div class="flex justify-center py-6">
          <button type="button"
            class="font-semibold text-sm mr-6 <%= if @show_less? do %>text-gray-700 cursor-pointer transition ease-in-out duration-200 border-b border-gray-200 hover:border-gray-400<% else %>text-gray-400 cursor-not-allowed<% end %>"
            phx-target="<%= @myself %>"
            phx-click="load_less">Show Less</button>

          <button type="button"
            class="font-semibold text-sm <%= if @show_more? do %>text-gray-700 cursor-pointer transition ease-in-out duration-200 border-b border-gray-200 hover:border-gray-400<% else %>text-gray-400 cursor-not-allowed<% end %>"
            phx-target="<%= @myself %>"
            phx-click="load_more">Show More</button>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("load_less", _params, socket) do
    if socket.assigns.show_less? do
      send(self(), {:params, :limit, -@inc_limit})
    end

    {:noreply, socket}
  end

  def handle_event("load_more", _params, socket) do
    if socket.assigns.show_more? do
      send(self(), {:params, :limit, @inc_limit})
    end

    {:noreply, socket}
  end
end
