defmodule Oban.Web.Queues.DetailComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Config
  alias Oban.Queue.BasicEngine

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    counts = Enum.find(assigns.counts, & &1["name"] == assigns.queue)
    gossip = Enum.filter(assigns.gossip, & &1["queue"] == assigns.queue)

    socket =
      socket
      |> assign(access: assigns.access, conf: assigns.conf, queue: assigns.queue)
      |> assign(counts: counts, gossip: gossip)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queue-details">
      <div class="flex justify-between items-center px-3 py-4 border-t border-b border-gray-200 dark:border-gray-700">
        <%= live_patch to: oban_path(@socket, :queues), class: "flex items-center" do %>
          <svg class="h-5 w-5 hover:text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd"></path></svg>
          <span class="text-lg capitalize font-bold ml-2"><%= @queue %> Queue</span>
        <% end %>

        <button rel="play_pause"
          class="block text-gray-500 hover:text-blue-500"
          title="Pause all instances"
          phx-click="play_pause"
          phx-target={@myself}
          phx-throttle="1000">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
        </button>
      </div>

      <table class="table-fixed w-full bg-blue-50 dark:bg-blue-300 dark:bg-opacity-25">
        <thead>
          <tr class="text-sm text-gray-600 dark:text-gray-300">
            <th scope="col" class="text-left font-normal pt-6 pb-2 px-3">Started</th>
            <th scope="col" class="text-left font-normal pt-6 pb-2 px-3">Executing</th>
            <th scope="col" class="text-left font-normal pt-6 pb-2 px-3">Available</th>
            <th scope="col" class="text-left font-normal pt-6 pb-2 px-3">Scheduled</th>
            <th scope="col" class="text-left font-normal pt-6 pb-2 px-3">Retryable</th>
            <th scope="col" class="text-left font-normal pt-6 pb-2 px-3">Cancelled</th>
            <th scope="col" class="text-left font-normal pt-6 pb-2 px-3">Discarded</th>
            <th scope="col" class="text-left font-normal pt-6 pb-2 px-3">Completed</th>
          </tr>
        </thead>
        <tbody>
          <tr class="text-lg text-gray-800 dark:text-gray-100 tabular">
            <td class="pb-6 px-3">
              <div class="flex items-center space-x-2">
                <svg class="w-4 h-4 text-gray-600 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <span><%= started_at(@gossip) %></span>
              </div>
            </td>

            <td class="pb-6 px-3">
              <div class="flex items-center space-x-2">
                <svg class="w-4 h-4 text-gray-600 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>
                <span><%= executing_count(@gossip) %></span>
              </div>
            </td>

            <%= for state <- ~w(available scheduled retryable cancelled discarded completed) do %>
              <td class="pb-6 px-3">
                <div class="flex items-center space-x-2">
                  <svg class="w-4 h-4 text-gray-600 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>
                  <span><%= integer_to_estimate(@counts[state]) %></span>
                </div>
              </td>
            <% end %>
          </tr>
        </tbody>
      </table>

      <div>
        <div class="flex items-center pl-3 pt-6 pb-3">
          <svg class="w-5 h-5 mr-1 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
          <h3 class="font-medium text-base">Global Configuration</h3>
        </div>

        <form class="flex w-full px-3 border-t border-gray-200 dark:border-gray-700">
          <div class="w-1/4 pr-3 pt-3 pb-6">
            <h3 class="flex items-center mb-4">
              <svg class="w-5 h-5 mr-1 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path></svg>
              <span class="text-base font-semibold">Local Concurrency</span>
            </h3>

            <label for="local_limit" class="block font-medium text-sm mb-2">Limit</label>
            <.number_input
              name="local_limit"
              value={local_limit(@gossip)}
              disabled={not can?(:scale_queues, @access)} />

            <div class="flex justify-end mt-4">
              <button class="block px-3 py-2 font-medium text-sm text-gray-600 dark:text-gray-100 bg-gray-300 dark:bg-blue-300 dark:bg-opacity-25 hover:bg-blue-500 hover:text-white dark:hover:bg-blue-500 dark:hover:text-white rounded-md shadow-sm">
                Save
              </button>
            </div>
          </div>

          <div id="global-limit-fields" class={"relative w-1/4 px-3 pt-3 pb-6 border-l border-r border-gray-200 dark:border-gray-700 #{if missing_pro?(@conf), do: "bg-white dark:bg-black bg-opacity-30"}"}>
            <%= if missing_pro?(@conf) do %>
              <.pro_blocker />
            <% end %>

            <div class={if missing_pro?(@conf), do: "opacity-20 cursor-not-allowed pointer-events-none select-none"}>
              <h3 class="flex items-center mb-4">
                <svg class="w-5 h-5 mr-1 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"></path></svg>
                <span class="text-base font-semibold">Global Concurrency</span>
              </h3>

              <label for="global_limit" class="block font-medium text-sm mb-2">Limit</label>
              <.number_input
                name="global_limit"
                value={global_limit(@gossip)}
                disabled={not can?(:scale_queues, @access)} />

              <div class="flex justify-end mt-4 opacity-20 cursor-not-allowed pointer-events-none select-none">
                <button class="block px-3 py-2 font-medium text-sm text-gray-600 dark:text-gray-100 bg-gray-300 dark:bg-blue-300 dark:bg-opacity-25 hover:bg-blue-500 hover:text-white dark:hover:bg-blue-500 dark:hover:text-white rounded-md shadow-sm">
                  Save
                </button>
              </div>
            </div>
          </div>

          <div id="rate-limit-fields" class={"relative w-1/2 pt-3 pb-6 pl-3 #{if missing_pro?(@conf), do: "bg-white dark:bg-black bg-opacity-30"}"}>
            <%= if missing_pro?(@conf) do %>
              <.pro_blocker />
            <% end %>

            <div class={if missing_pro?(@conf), do: "opacity-20 cursor-not-allowed pointer-events-none select-none"}>
              <h3 class="flex items-center mb-4">
                <svg class="w-5 h-5 mr-1 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6"></path></svg>
                <span class="text-base font-semibold">Rate Limiting</span>
              </h3>

              <div class="flex w-full space-x-3 mb-6">
                <div class="w-1/2">
                  <label for="rate_limit_allowed" class="block font-medium text-sm mb-2">Allowed</label>
                  <.number_input
                    name="rate_limit_allowed"
                    value={rate_limit_allowed(@gossip)}
                    disabled={not can?(:scale_queues, @access)} />
                </div>

                <div class="w-1/2">
                  <label for="rate_limit_period" class="block font-medium text-sm mb-2">Period</label>
                  <.number_input
                    name="rate_limit_period"
                    value={rate_limit_period(@gossip)}
                    disabled={not can?(:scale_queues, @access)} />
                </div>
              </div>

              <div class="flex w-full space-x-3">
                <div class="w-1/2">
                  <label for="rate_limit_fields" class="block font-medium text-sm mb-2">Partition Fields</label>
                  <select
                    id="rate_limit_fields"
                    name="rate_limit_fields"
                    class="block w-full font-mono text-sm pl-3 pr-10 py-2 shadow-sm border-gray-300 dark:border-gray-500 bg-gray-100 dark:bg-gray-800 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    disabled={not can?(:scale_queues, @access)}>
                    <%= options_for_select(["Disabled": nil, "Worker": "worker", "Args": "args", "Worker + Args": "worker+args"], rate_limit_partition_fields(@gossip)) %>
                  </select>
                </div>

                <div class="w-1/2 opacity-30 cursor-not-allowed pointer-events-none select-none">
                  <label for="rate_limit_keys" class="block font-medium text-sm mb-2">Partition Keys</label>

                  <input
                    type="text"
                    id="rate_limit_keys"
                    name="rate_limit_keys"
                    class="block w-full font-mono text-sm py-2 shadow-sm border-gray-300 dark:border-gray-500 bg-gray-100 dark:bg-gray-800 rounded-md focus:ring-blue-400 focus:border-blue-400"
                    value={rate_limit_partition_keys(@gossip)}
                    disabled={not can?(:scale_queues, @access)}>
                </div>
              </div>

              <div class="flex justify-end mt-4 opacity-30 cursor-not-allowed pointer-events-none select-none">
                <button class="block px-3 py-2 font-medium text-sm text-gray-600 dark:text-gray-100 bg-gray-300 dark:bg-blue-300 dark:bg-opacity-25 hover:bg-blue-500 hover:text-white dark:hover:bg-blue-500 dark:hover:text-white rounded-md shadow-sm">
                  Save
                </button>
              </div>
            </div>
          </div>
        </form>
      </div>

      <div id="queue-instances" class="border-t border-gray-200 dark:border-gray-700">
        <div class="flex items-center pl-3 pt-6 pb-3">
          <svg class="w-5 h-5 mr-1 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
          <h3 class="font-medium text-base">Instance Configuration</h3>
        </div>

        <table class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700 border-t border-gray-200 dark:border-gray-700">
          <thead>
            <tr class="text-sm text-gray-500 dark:text-gray-400">
              <th scope="col" class="w-1/2 text-left text-xs font-medium uppercase tracking-wider pl-3 py-3">Node/Name</th>
              <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3">Executing</th>
              <th scope="col" class="w-16 text-right text-xs font-medium uppercase tracking-wider py-3">Started</th>
              <th scope="col" class="w-8 text-left text-xs font-medium uppercase tracking-wider pl-6 py-3">Pause</th>
              <th scope="col" class="w-32 text-left text-xs font-medium uppercase tracking-wider pr-3 py-3">Scale</th>
            </tr>
          </thead>

          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <%= for gossip <- @gossip do %>
              <tr>
                <td class="pl-3 py-3"><%= node_name(gossip) %></td>
                <td class="text-right py-3"><%= executing_count(gossip) %></td>
                <td class="text-right py-3"><%= started_at(gossip) %></td>
                <td class="pl-6 py-3">
                  <button rel="play_pause"
                    class="block text-gray-500 hover:text-blue-500"
                    title="Pause or resume queue"
                    phx-click="play_pause"
                    phx-target={@myself}
                    phx-throttle="1000">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                  </button>
                </td>
                <td class="pr-3 py-3">
                  <form class="flex space-x-3">
                    <.number_input name="local_limit" value={gossip["local_limit"]} disabled={not can?(:scale_queues, @access)} />
                    <button class="block px-3 py-2 font-medium text-sm text-gray-600 dark:text-gray-100 bg-gray-300 dark:bg-blue-300 dark:bg-opacity-25 hover:bg-blue-500 hover:text-white dark:hover:bg-blue-500 dark:hover:text-white rounded-md shadow-sm">Scale</button>
                  </form>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Components

  defp number_input(assigns) do
    ~H"""
    <div class="flex">
      <input
        type="text"
        id={@name}
        name={@name}
        placeholder="Off"
        disabled={@disabled}
        class="w-1/2 flex-1 min-w-0 block font-mono text-sm shadow-sm border-gray-300 dark:border-gray-500 bg-gray-100 dark:bg-gray-800 rounded-l-md focus:ring-blue-400 focus:border-blue-400"
        value={@value}>

      <div class="w-9">
        <button class="block -ml-px px-3 py-1 bg-gray-300 dark:bg-gray-500 rounded-tr-md hover:bg-gray-200 dark:hover:bg-gray-600 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500">
          <svg class="w-3 h-3 text-gray-600 dark:text-gray-200" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"></path></svg>
        </button>

        <button class="block -ml-px px-3 py-1 bg-gray-300 dark:bg-gray-500 rounded-br-md hover:bg-gray-200 dark:hover:bg-gray-600 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500">
          <svg class="w-3 h-3 text-gray-600 dark:text-gray-200" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path></svg>
        </button>
      </div>
    </div>
    """
  end

  defp pro_blocker(assigns) do
    ~H"""
    <span rel="requires-pro" class="text-center w-full text-sm text-gray-600 dark:text-gray-300 absolute top-1/2 -mt-6 -ml-3">
      Requires <a href="https://getoban.pro" class="text-blue-500 font-semibold">Oban Pro <svg class="w-3 h-3 inline-block align-text-top" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg></a>
    </span>
    """
  end

  # Helpers

  defp local_limit(gossip) do
    gossip
    |> Enum.map(& &1["local_limit"])
    |> Enum.max()
  end

  defp global_limit(gossip) do
    Enum.find_value(gossip, & &1["global_limit"])
  end

  defp rate_limit_allowed(gossip) do
    gossip
    |> Enum.map(& &1["rate_limit"])
    |> Enum.filter(&is_map/1)
    |> Enum.find_value(& &1["allowed"])
  end

  defp rate_limit_period(gossip) do
    gossip
    |> Enum.map(& &1["rate_limit"])
    |> Enum.filter(&is_map/1)
    |> Enum.find_value(& &1["period"])
  end

  defp rate_limit_partition_fields(gossip) do
    case first_rate_limit(gossip) do
      %{"partition" => %{"fields" => fields}} -> Enum.join(fields, "+")
      _ -> nil
    end
  end

  defp rate_limit_partition_keys(gossip) do
    case first_rate_limit(gossip) do
      %{"partition" => %{"keys" => keys}} -> Enum.join(keys, ", ")
      _ -> nil
    end
  end

  defp first_rate_limit(gossip) do
    gossip
    |> Enum.map(& &1["rate_limit"])
    |> Enum.filter(&is_map/1)
    |> List.first()
  end

  # Pro Helpers

  defp missing_pro?(%Config{engine: engine}), do: engine == BasicEngine
end
