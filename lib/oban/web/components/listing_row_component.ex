defmodule Oban.Web.ListingRowComponent do
  use Oban.Web, :live_component

  def mount(socket) do
    {:ok, assign(socket, hidden?: false, selected?: false)}
  end

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       job: assigns.job,
       selected?: MapSet.member?(assigns.selected, assigns.job.id),
       hidden?: Map.get(assigns.job, :hidden?, false)
     )}
  end

  def render(assigns) do
    ~L"""
    <li class="flex justify-between bg-white border-b border-gray-100 transition ease-in-out duration-200 <%= if @hidden? do %>opacity-25 pointer-events-none<% end %> <%= if @selected? do %>bg-blue-100<% else %>hover:bg-green-50<% end %>">
      <div class="flex justify-start">
        <button class="flex-none block pl-3 py-3 " phx-target="<%= @myself %>" phx-click="toggle_select">
          <%= if @selected? do %>
            <svg class="text-blue-500 h-5 w-5" fill="currentColor" viewBox="0 0 20 20"><path d="M16 2a2 2 0 012 2v12a2 2 0 01-2 2H4a2 2 0 01-2-2V4a2 2 0 012-2h12zm-2.7 4.305l-5.31 5.184L6.7 10.145a.967.967 0 00-1.41 0 1.073 1.073 0 000 1.47l1.994 2.08a.967.967 0 001.409 0l6.014-5.92c.39-.406.39-1.064 0-1.47a.967.967 0 00-1.409 0z" fill-rule="evenodd"/></svg>
          <% else %>
            <svg class="text-gray-400 hover:text-blue-500 h-5 w-5" fill="currentColor" viewBox="0 0 20 20"><path d="M15.25 2H4.75A2.75 2.75 0 002 4.75v10.5A2.75 2.75 0 004.75 18h10.5A2.75 2.75 0 0018 15.25V4.75A2.75 2.75 0 0015.25 2zM4.75 4h10.5a.75.75 0 01.75.75v10.5a.75.75 0 01-.75.75H4.75a.75.75 0 01-.75-.75V4.75A.75.75 0 014.75 4z" fill-rule="nonzero"/></svg>
          <% end %>
        </button>

        <div class="flex-auto max-w-xl overflow-hidden pl-3 py-3">
          <span class="text-sm text-gray-500 tabular"><%= @job.id %></span>
          <span class="font-semibold text-sm text-gray-700 cursor-pointer transition ease-in-out duration-200 border-b border-gray-200 hover:border-gray-400 ml-1" phx-target="<%= @myself %>" phx-click="toggle_worker"><%= @job.worker %></span>
          <span class="block font-mono truncate text-xs text-gray-500 mt-2"><%= inspect(@job.args) %></span>
        </div>
      </div>

      <div class="flex justify-end items-center">
        <div class="tabular text-sm truncate text-gray-500 text-right w-32 pl-3">
          <%= @job.queue %>
        </div>

        <div class="tabular text-sm text-gray-500 text-right w-20 pl-3">
          <%= @job.attempt %> ⁄ <%= @job.max_attempts %>
        </div>

        <div class="tabular text-sm text-gray-500 text-right w-20 pl-3">
          <%= relative_time(@job.state, @job) %>
        </div>

        <button class="block px-3 py-3 text-gray-400 hover:text-blue-500" phx-target="<%= @myself %>" phx-click="show_details">
          <svg fill="currentColor" viewBox="0 0 20 20" class="h-5 w-5"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
        </button>
      </div>
    </li>
    """
  end

  def handle_event("toggle_select", _params, socket) do
    if socket.assigns.selected? do
      send(self(), {:deselect_job, socket.assigns.job})
    else
      send(self(), {:select_job, socket.assigns.job})
    end

    {:noreply, assign(socket, :selected?, not socket.assigns.selected?)}
  end

  def handle_event("toggle_worker", _params, socket) do
    send(self(), {:filter_worker, socket.assigns.job.worker})

    {:noreply, socket}
  end

  def handle_event("show_details", _params, socket) do
    send(self(), {:show_details, socket.assigns.job})

    {:noreply, socket}
  end
end
