defmodule ObanWeb.HeaderComponent do
  use ObanWeb.Web, :live_component

  def update(assigns, socket) do
    {:ok,
     assign(
       socket,
       numerator: length(assigns.jobs),
       denominator: state_count(assigns.stats, assigns.filters.state),
       state: assigns.filters.state
     )}
  end

  def render(assigns) do
    ~L"""
    <div>
      <h2 class="text-xl font-bold">Jobs <span class="text-gray-500 font-normal tabular">(<%= @numerator %>/<%= @denominator %> <%= String.capitalize(@state) %>)</span></h2>
    </div>
    """
  end

  def state_count(stats, state) do
    state
    |> :proplists.get_value(stats, %{count: 0})
    |> Map.get(:count)
  end
end
