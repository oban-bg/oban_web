defmodule Oban.Web.Jobs.HeaderComponent do
  use Oban.Web, :live_component

  def update(assigns, socket) do
    %{jobs: jobs, selected: selected} = assigns

    select_mode =
      cond do
        Enum.any?(selected) and Enum.count(selected) == Enum.count(jobs) -> :all
        Enum.any?(selected) -> :some
        true -> :none
      end

    {:ok,
     assign(
       socket,
       numerator: Enum.count(jobs),
       denominator: state_count(assigns.counts, assigns.params),
       select_mode: select_mode,
       state: get_in(assigns, [:params, :state]) || "executing"
     )}
  end

  def render(assigns) do
    ~H"""
    <div id="jobs-header" class="flex items-center">
      <button
        id="toggle-select"
        class="block text-gray-400 hover:text-blue-500"
        data-title="Select All"
        phx-target={@myself}
        phx-click="toggle-select"
        phx-hook="Tippy"
        type="button">
        <%= if @select_mode == :all do %>
          <svg class="text-blue-500 h-5 w-5" fill="currentColor" viewBox="0 0 20 20"><path d="M16 2a2 2 0 012 2v12a2 2 0 01-2 2H4a2 2 0 01-2-2V4a2 2 0 012-2h12zm-2.7 4.305l-5.31 5.184L6.7 10.145a.967.967 0 00-1.41 0 1.073 1.073 0 000 1.47l1.994 2.08a.967.967 0 001.409 0l6.014-5.92c.39-.406.39-1.064 0-1.47a.967.967 0 00-1.409 0z" fill-rule="evenodd"/></svg>
        <% end %>

        <%= if @select_mode == :some do %>
          <svg class="text-blue-500 h-5 w-5" fill="currentColor" viewBox="0 0 20 20"><path d="M16 2a2 2 0 012 2v12a2 2 0 01-2 2H4a2 2 0 01-2-2V4a2 2 0 012-2h12zm-2 7H6l-.117.007a1 1 0 000 1.986L6 11h8l.117-.007A1 1 0 0014 9z" fill-rule="evenodd"/></svg>
        <% end %>

        <%= if @select_mode == :none do %>
          <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20"><path d="M15.25 2H4.75A2.75 2.75 0 002 4.75v10.5A2.75 2.75 0 004.75 18h10.5A2.75 2.75 0 0018 15.25V4.75A2.75 2.75 0 0015.25 2zM4.75 4h10.5a.75.75 0 01.75.75v10.5a.75.75 0 01-.75.75H4.75a.75.75 0 01-.75-.75V4.75A.75.75 0 014.75 4z" fill-rule="nonzero"/></svg>
        <% end %>
      </button>

      <h2 class="text-lg dark:text-gray-200 leading-4 font-bold ml-2">Jobs</h2>
      <h3 class="text-lg ml-2 text-gray-500 leading-4 font-normal tabular">(<%= @numerator %>/<%= integer_to_delimited(@denominator) %> <%= String.capitalize(@state) %>)</h3>
    </div>
    """
  end

  def state_count(counts, %{state: state}) do
    Enum.reduce(counts, 0, &(Map.get(&1, state, 0) + &2))
  end

  def state_count(_stats, _params), do: 0

  def handle_event("toggle-select", _params, socket) do
    if socket.assigns.select_mode == :none do
      send(self(), :select_all)
    else
      send(self(), :deselect_all)
    end

    {:noreply, socket}
  end
end
