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
       # state_count(assigns.counts, assigns.params),
       denominator: 10,
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
        type="button"
      >
        <%= case @select_mode do %>
          <% :all -> %>
            <Icons.check_selected_solid class="w-5 h-5 text-blue-500" />
          <% :some -> %>
            <Icons.check_partial_solid class="w-5 h-5 text-blue-500" />
          <% :none -> %>
            <Icons.check_empty class="w-5 h-5" />
        <% end %>
      </button>

      <h2 class="text-lg dark:text-gray-200 leading-4 font-bold ml-2">Jobs</h2>
      <h3 class="text-lg ml-2 text-gray-500 leading-4 font-normal tabular">
        (<%= @numerator %>/<%= integer_to_delimited(@denominator) %> <%= String.capitalize(@state) %>)
      </h3>
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
