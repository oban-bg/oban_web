defmodule Oban.Web.Jobs.TableComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Jobs.RowComponent
  alias Oban.Web.SortComponent

  @inc_limit 20
  @max_limit 200
  @min_limit 20

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(jobs: assigns.jobs, params: assigns.params)
      |> assign(resolver: assigns.resolver, selected: assigns.selected)
      |> assign(show_less?: assigns.params.limit > @min_limit)
      |> assign(show_more?: assigns.params.limit < @max_limit)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <table id="jobs-table" class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700">
      <thead>
        <tr class="text-gray-500 dark:text-gray-400">
          <th scope="col" class="w-10"></th>
          <th scope="col" class="text-left text-xs font-medium uppercase tracking-wider py-3">
            <SortComponent.link label="worker" params={@params} socket={@socket} page={:jobs} justify="start" />
          </th>
          <th scope="col" class="w-32 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
            <SortComponent.link label="queue" params={@params} socket={@socket} page={:jobs} justify="end" />
          </th>
          <th scope="col" class="w-20 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
            <SortComponent.link label="attempt" params={@params} socket={@socket} page={:jobs} justify="end" />
          </th>
          <th scope="col" class="w-20 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
            <SortComponent.link label="time" params={@params} socket={@socket} page={:jobs} justify="end" />
          </th>
          <th scope="col" class="w-10"></th>
        </tr>
      </thead>

      <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
        <%= if Enum.any?(@jobs) do %>
          <%= for job <- @jobs do %>
            <.live_component
              id={job.id}
              module={RowComponent}
              job={job}
              resolver={@resolver}
              selected={@selected}
              socket={@socket} />
          <% end %>
        <% else %>
          <tr>
            <td colspan="6" class="text-lg text-center text-gray-500 dark:text-gray-400 py-12">
              <div class="flex items-center justify-center space-x-2">
                <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <span>No jobs match the current set of filters.</span>
              </div>
            </td>
          </tr>
        <% end %>
      </tbody>

      <tfoot>
        <tr>
          <td colspan="6" class="py-6">
            <div class="flex items-center justify-center space-x-2">
              <button type="button"
                class={"font-semibold text-sm mr-6 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 #{activity_class(@show_less?)}"}
                phx-target={@myself}
                phx-click="load_less">Show Less</button>

              <button type="button"
                class={"font-semibold text-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 #{activity_class(@show_more?)}"}
                phx-target={@myself}
                phx-click="load_more">Show More</button>
            </div>
          </td>
        </tr>
      </tfoot>
    </table>
    """
  end

  @impl Phoenix.LiveComponent
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

  defp activity_class(true) do
    """
    text-gray-700 dark:text-gray-300 cursor-pointer transition ease-in-out duration-200 border-b
    border-gray-200 dark:border-gray-800 hover:border-gray-400
    """
  end

  defp activity_class(_), do: "text-gray-400 dark:text-gray-600 cursor-not-allowed"
end
