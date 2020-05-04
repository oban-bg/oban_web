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
    <div class="flex items-center">
      <button class="block text-gray-400 hover:text-blue-500">
        <svg fill="currentColor" viewBox="0 0 20 20" class="h-5 w-5"><path d="M15.25 2H4.75A2.75 2.75 0 002 4.75v10.5A2.75 2.75 0 004.75 18h10.5A2.75 2.75 0 0018 15.25V4.75A2.75 2.75 0 0015.25 2zM4.75 4h10.5a.75.75 0 01.75.75v10.5a.75.75 0 01-.75.75H4.75a.75.75 0 01-.75-.75V4.75A.75.75 0 014.75 4z" fill-rule="nonzero"/></svg>
      </button>

      <h2 class="text-lg font-bold ml-2">Jobs</h2>
      <h3 class="text-lg ml-1 text-gray-500 font-normal tabular">(<%= @numerator %>/<%= @denominator %> <%= String.capitalize(@state) %>)</h3>
    </div>
    """
  end

  def state_count(stats, state) do
    state
    |> :proplists.get_value(stats, %{count: 0})
    |> Map.get(:count)
  end
end
