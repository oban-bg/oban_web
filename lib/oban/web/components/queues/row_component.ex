defmodule Oban.Web.Queues.RowComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Timing

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~L"""
    <li id="queue-<%= @queue.id %>" class="group flex justify-between py-3 px-3 bg-white dark:bg-gray-900 border-b border-gray-100 dark:border-gray-800 hover:bg-blue-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25">
      <button class="block pr-3 text-gray-400 hover:text-blue-500">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
      </button>

      <span rel="name" class="w-60"><%= @queue.queue %></span>
      <span rel="execu" class="w-24 pl-3 ml-auto text-right tabular"><%= integer_to_estimate(@queue.executing) %></span>
      <span rel="avail" class="w-24 pl-3 text-right tabular"><%= integer_to_estimate(@queue.available) %></span>
      <span rel="compl" class="w-24 pl-3 text-right tabular"><%= integer_to_estimate(@queue.completed) %></span>
      <span rel="nodes" class="w-20 pl-3 text-right tabular"><%= MapSet.size(@queue.nodes) %></span>
      <span rel="local" class="w-20 pl-3 text-right tabular"><%= local_limit(@queue.local_limits) %></span>
      <span rel="total" class="w-20 pl-3 text-right tabular"><%= total_limit(@queue.global_limits, @queue.local_limits) %></span>
      <span rel="uptime" class="w-32 text-right tabular"><%= Timing.to_words(@queue.uptime) %></span>

      <div class="w-24 pl-3 flex justify-end">
        <button class="block pr-3 text-gray-400 hover:text-blue-500">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
        </button>

        <button class="block text-gray-400 hover:text-blue-500">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4"></path></svg>
        </button>
      </div>
    </li>
    """
  end

  defp local_limit(limits) do
    case Enum.min_max(limits) do
      {min, min} -> min
      {min, max} -> "#{min}..#{max}"
    end
  end

  defp total_limit([global | _], _limits) when is_integer(global), do: global
  defp total_limit([_head | tail], limits), do: total_limit(limits, tail)
  defp total_limit([], limits), do: Enum.sum(limits)
end
