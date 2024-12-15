defmodule Oban.Web.Jobs.HeaderComponent do
  use Oban.Web, :live_component

  def update(assigns, socket) do
    %{jobs: jobs, params: params, selected: selected} = assigns

    select_mode =
      cond do
        Enum.any?(selected) and Enum.count(selected) == Enum.count(jobs) -> :all
        Enum.any?(selected) -> :some
        true -> :none
      end

    state = Map.get(params, :state, "executing")

    {:ok, assign(socket, select_mode: select_mode, state: state)}
  end

  def render(assigns) do
    ~H"""
    <div id="jobs-header" class="h-10 w-44 pr-3 flex-none flex items-center">
      <button
        id="toggle-select"
        class="mt-0.5 text-gray-400 hover:text-blue-500"
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

      <h2 class="capitalize ml-2 text-base font-semibold dark:text-gray-200">{@state} Jobs</h2>
    </div>
    """
  end

  def handle_event("toggle-select", _params, socket) do
    if socket.assigns.select_mode == :none do
      send(self(), :select_all)
    else
      send(self(), :deselect_all)
    end

    {:noreply, socket}
  end
end
