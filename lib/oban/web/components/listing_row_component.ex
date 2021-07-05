defmodule Oban.Web.ListingRowComponent do
  use Oban.Web, :live_component

  def mount(socket) do
    {:ok, assign(socket, hidden?: false, selected?: false)}
  end

  def update(%{job: job, selected: selected}, socket) do
    {:ok,
     assign(socket,
       job: job,
       selected?: MapSet.member?(selected, job.id),
       hidden?: Map.get(job, :hidden?, false)
     )}
  end

  def render(assigns) do
    ~L"""
    <li id="job-<%= @job.id %>" class="group flex justify-between bg-white dark:bg-gray-900 border-b border-gray-100 dark:border-gray-800 <%= if @hidden? do %>opacity-25 pointer-events-none js-hidden<% end %> <%= if @selected? do %>bg-blue-100<% else %>hover:bg-blue-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25<% end %>">
      <div class="flex justify-start">
        <button class="js-toggle flex-none block pl-3 py-3" phx-target="<%= @myself %>" phx-click="toggle_select">
          <%= if @selected? do %>
            <svg class="text-blue-500 h-5 w-5" fill="currentColor" viewBox="0 0 20 20"><path d="M16 2a2 2 0 012 2v12a2 2 0 01-2 2H4a2 2 0 01-2-2V4a2 2 0 012-2h12zm-2.7 4.305l-5.31 5.184L6.7 10.145a.967.967 0 00-1.41 0 1.073 1.073 0 000 1.47l1.994 2.08a.967.967 0 001.409 0l6.014-5.92c.39-.406.39-1.064 0-1.47a.967.967 0 00-1.409 0z" fill-rule="evenodd"/></svg>
          <% else %>
            <svg class="text-gray-400 hover:text-blue-500 h-5 w-5" fill="currentColor" viewBox="0 0 20 20"><path d="M15.25 2H4.75A2.75 2.75 0 002 4.75v10.5A2.75 2.75 0 004.75 18h10.5A2.75 2.75 0 0018 15.25V4.75A2.75 2.75 0 0015.25 2zM4.75 4h10.5a.75.75 0 01.75.75v10.5a.75.75 0 01-.75.75H4.75a.75.75 0 01-.75-.75V4.75A.75.75 0 014.75 4z" fill-rule="nonzero"/></svg>
          <% end %>
        </button>

        <%= live_patch to: oban_path(@socket, :jobs, @job), class: "flex-auto cursor-pointer max-w-xl overflow-hidden pl-3 py-3" do %>
          <span rel="jid" class="text-sm text-gray-500 dark:text-gray-400 tabular"><%= @job.id %></span>
          <span rel="worker" class="font-semibold text-sm text-gray-700 dark:text-gray-300 ml-1"><%= @job.worker %></span>
          <span rel="args" class="block font-mono truncate text-xs text-gray-500 dark:text-gray-400 dark:group-hover:text-gray-300 mt-2"><%= inspect(@job.args) %></span>
        <% end %>
      </div>

      <div class="flex justify-end items-center">
        <div class="tabular text-sm truncate text-gray-500 dark:group-hover:text-gray-300 text-right w-32 pl-3">
          <%= @job.queue %>
        </div>

        <div class="tabular text-sm text-gray-500 dark:group-hover:text-gray-300 text-right w-20 pl-3">
          <%= @job.attempt %> ⁄ <%= @job.max_attempts %>
        </div>

        <div class="tabular text-sm text-gray-500 dark:group-hover:text-gray-300 text-right w-20 pl-3">
          <%= relative_time(@job.state, @job) %>
        </div>

        <button rel="worker-<%= @job.worker %>" class="block px-3 py-3 text-gray-400 hover:text-blue-500" title="Search for jobs with the same worker" phx-target="<%= @myself %>" phx-click="toggle_worker">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 21h7a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v11m0 5l4.879-4.879m0 0a3 3 0 104.243-4.242 3 3 0 00-4.243 4.242z"></path></svg>
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
    send(self(), {:params, :terms, socket.assigns.job.worker})

    {:noreply, socket}
  end
end
