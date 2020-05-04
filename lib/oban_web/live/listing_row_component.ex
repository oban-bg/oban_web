defmodule ObanWeb.ListingRowComponent do
  use ObanWeb.Web, :live_component

  def mount(socket) do
    {:ok, assign(socket, selected?: false, show_menu?: false)}
  end

  def render(assigns) do
    ~L"""
    <li class="flex justify-between border-b border-gray-100 hover:bg-green-50">
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
          <span class="font-semibold text-sm text-gray-700 cursor-pointer transition ease-in-out duration-100 border-b border-gray-200 hover:border-gray-400 ml-1"><%= @job.worker %></span>
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

        <div class="relative">
          <button class="block z-auto pl-3 py-3 text-gray-400 hover:text-blue-500 focus:outline-none" phx-target="<%= @myself %>" phx-click="toggle_menu">
            <svg fill="currentColor" viewBox="0 0 20 20" class="h-5 w-5"><path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z"></path></svg>
          </button>

          <div class="origin-top-right absolute z-10 right-0 -mt-1 w-48 rounded-md shadow-lg <%= if @show_menu? do %>block<% else %>hidden<% end %>">
            <div class="rounded-md bg-white shadow-xs">
              <%= if @job.state in ~w(inserted scheduled available executing retryable) do %>
                <a href="#"
                   class="group flex items-center px-3 py-2 text-sm leading-5 text-gray-600 hover:bg-gray-100 hover:text-gray-700 focus:outline-none focus:bg-gray-100 focus:text-gray-900"
                   phx-target="<%= @myself %>" phx-click="cancel">
                  <svg class="mr-2 h-5 w-5 text-gray-400 group-hover:text-gray-500 group-focus:text-gray-500" fill="currentColor" viewBox="0 0 20 20"><path d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
                  Cancel
                </a>
              <% end %>

              <%= if @job.state in ~w(inserted scheduled) do %>
                <a href="#"
                   class="group flex items-center px-3 py-2 text-sm leading-5 text-gray-600 hover:bg-gray-100 hover:text-gray-700 focus:outline-none focus:bg-gray-100 focus:text-gray-900"
                   phx-target="<%= @myself %>" phx-click="run_now">
                  <svg class="mr-2 h-5 w-5 text-gray-400 group-hover:text-gray-500 group-focus:text-gray-500" fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
                  Run Now
                </a>
              <% end %>

              <%= if @job.state in ~w(completed retryable) do %>
                <a href="#"
                   class="group flex items-center px-3 py-2 text-sm leading-5 text-gray-600 hover:bg-gray-100 hover:text-gray-700 focus:outline-none focus:bg-gray-100 focus:text-gray-900"
                   phx-target="<%= @myself %>" phx-click="retry">
                  <svg class="mr-2 h-5 w-5 text-gray-400 group-hover:text-gray-500 group-focus:text-gray-500" fill="currentColor" viewBox="0 0 20 20"><path d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
                  Retry
                </a>
              <% end %>

              <%= if @job.state in ~w(inserted scheduled available completed retryable discarded) do %>
                <a href="#"
                   class="group flex items-center px-3 py-2 text-sm leading-5 text-gray-600 hover:bg-gray-100 hover:text-gray-700 focus:outline-none focus:bg-gray-100 focus:text-gray-900"
                   phx-target="<%= @myself %>" phx-click="delete">
                  <svg class="mr-2 h-5 w-5 text-gray-400 group-hover:text-gray-500 group-focus:text-gray-500" fill="currentColor" viewBox="0 0 20 20"><path d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
                  Delete
                </a>
              <% end %>
            </div>
          </div>
        </div>

        <button class="block px-3 py-3 text-gray-400 hover:text-blue-500">
          <svg fill="currentColor" viewBox="0 0 20 20" class="h-5 w-5"><path d="M11 3a1 1 0 100 2h2.586l-6.293 6.293a1 1 0 101.414 1.414L15 6.414V9a1 1 0 102 0V4a1 1 0 00-1-1h-5z"></path><path d="M5 5a2 2 0 00-2 2v8a2 2 0 002 2h8a2 2 0 002-2v-3a1 1 0 10-2 0v3H5V7h3a1 1 0 000-2H5z"></path></svg>
        </button>
      </div>
    </li>
    """
  end

  def handle_event("toggle_select", _params, socket) do
    {:noreply, assign(socket, :selected?, not socket.assigns.selected?)}
  end

  def handle_event("toggle_menu", _params, socket) do
    {:noreply, assign(socket, show_menu?: not socket.assigns.show_menu?)}
  end

  def handle_event("cancel", _params, socket) do
    send(self(), {:cancel_job, socket.assigns.job})

    {:noreply, socket}
  end

  def handle_event("run_now", _params, socket) do
    send(self(), {:deschedule_job, socket.assigns.job})

    {:noreply, socket}
  end

  def handle_event("retry", _params, socket) do
    send(self(), {:deschedule_job, socket.assigns.job})

    {:noreply, socket}
  end

  def handle_event("delete", _params, socket) do
    send(self(), {:delete_job, socket.assigns.job})

    {:noreply, socket}
  end
end
