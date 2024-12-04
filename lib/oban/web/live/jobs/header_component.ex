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
    <div id="jobs-header" class="h-10 pr-3 flex-none flex items-center">
      <Core.all_checkbox click="toggle-select" checked={@select_mode} myself={@myself} />

      <h2 class="text-base font-semibold dark:text-gray-200">Jobs</h2>
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
