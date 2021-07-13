defmodule Oban.Web.Jobs.SidebarComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Jobs.{NodeComponent, QueueComponent, StateComponent}

  @ordered_states ~w(executing available scheduled retryable cancelled discarded completed)

  def mount(socket) do
    {:ok, assign(socket, show_nodes?: true, show_states?: true, show_queues?: true)}
  end

  def update(assigns, socket) do
    %{gossip: gossip, counts: counts} = assigns

    {:ok,
     assign(
       socket,
       access: assigns.access,
       node_stats: node_stats(gossip),
       state_stats: state_stats(counts),
       queue_stats: queue_stats(gossip, counts),
       params: assigns.params
     )}
  end

  def render(assigns) do
    ~L"""
    <div id="nodes" class="bg-white dark:bg-gray-900 w-fill mb-3 rounded-md shadow-lg overflow-hidden md:w-84">
      <header class="group flex justify-between items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
        <span class="dark:text-gray-200 font-bold">Nodes</span>

        <div class="group-hover:hidden">
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-10">Exec</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-10">Limit</span>
        </div>

        <div class="hidden group-hover:block">
          <button class="block w-5 h-5 text-gray-400 dark:text-gray-600 hover:text-blue-500" title="Minimize or maximize" phx-click="toggle" phx-value-menu="nodes" phx-target="<%= @myself %>">
            <%= if @show_nodes? do %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% else %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% end %>
          </button>
        </div>
      </header>

      <ul class="<%= if @show_nodes? do %>block<% else %>hidden<% end %>">
        <%= for {name, stat} <- @node_stats do %>
          <%= live_component @socket, NodeComponent, id: name, params: @params, name: name, stat: stat %>
        <% end %>
      </ul>
    </div>

    <div id="states" class="bg-white dark:bg-gray-900 w-full mb-3 rounded-md shadow-lg overflow-hidden md:w-84">
      <header class="group flex justify-between items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
        <span class="dark:text-gray-200 font-bold">States</span>

        <div class="group-hover:hidden">
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-10">Count</span>
        </div>

        <div class="hidden group-hover:block">
          <button class="block w-5 h-5 text-gray-400 dark:text-gray-600 hover:text-blue-500" title="Minimize or maximize" phx-click="toggle" phx-value-menu="states" phx-target="<%= @myself %>">
            <%= if @show_states? do %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% else %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% end %>
          </button>
        </div>
      </header>

      <ul class="<%= if @show_states? do %>block<% else %>hidden<% end %>">
        <%= for {name, stat} <- @state_stats do %>
          <%= live_component @socket, StateComponent, id: name, params: @params, name: name, stat: stat %>
        <% end %>
      </ul>
    </div>

    <div id="queues" class="bg-white dark:bg-gray-900 w-full rounded-md shadow-lg overflow-hidden md:w-84">
      <header class="group flex justify-between items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
        <span class="dark:text-gray-200 font-bold">Queues</span>

        <div class="group-hover:hidden">
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-10">Exec</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-10">Limit</span>
          <span class="text-xs text-gray-500 uppercase inline-block text-right w-10">Avail</span>
        </div>

        <div class="hidden group-hover:block">
          <button class="block w-5 h-5 text-gray-400 dark:text-gray-600 hover:text-blue-500" title="Minimize or maximize" phx-click="toggle" phx-value-menu="queues" phx-target="<%= @myself %>">
            <%= if @show_queues? do %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% else %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-11a1 1 0 10-2 0v2H7a1 1 0 100 2h2v2a1 1 0 102 0v-2h2a1 1 0 100-2h-2V7z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% end %>
          </button>
        </div>
      </header>

      <ul class="<%= if @show_queues? do %>block<% else %>hidden<% end %>">
        <%= for {name, stat} <- @queue_stats do %>
          <%= live_component @socket, QueueComponent, id: name, access: @access, params: @params, name: name, stat: stat %>
        <% end %>
      </ul>
    </div>
    """
  end

  def node_stats(gossip) do
    for payload <- gossip, reduce: %{} do
      acc ->
        limit = payload_limit(payload)
        count = payload |> Map.get("running", []) |> length()

        full_name =
          [payload["name"], payload["node"]]
          |> Enum.join("/")
          |> String.trim_leading("Elixir.")

        Map.update(acc, full_name, %{count: count, limit: limit}, fn map ->
          %{map | count: map.count + count, limit: map.limit + limit}
        end)
    end
  end

  def state_stats(counts) do
    for state <- @ordered_states do
      total = Enum.reduce(counts, 0, &(&1[state] + &2))

      {state, %{count: total}}
    end
  end

  def queue_stats(gossip, counts) do
    avail_counts = Map.new(counts, fn %{"name" => key, "available" => val} -> {key, val} end)
    execu_counts = Map.new(counts, fn %{"name" => key, "executing" => val} -> {key, val} end)

    total_limits =
      Enum.reduce(gossip, %{}, fn payload, acc ->
        limit = payload_limit(payload)

        Map.update(acc, payload["queue"], limit, &(&1 + limit))
      end)

    local_limits = Map.new(gossip, fn payload -> {payload["queue"], payload_limit(payload)} end)

    pause_states =
      Enum.reduce(gossip, %{}, fn %{"paused" => paused, "queue" => queue}, acc ->
        Map.update(acc, queue, paused, &(&1 or paused))
      end)

    [avail_counts, execu_counts, total_limits]
    |> Enum.flat_map(&Map.keys/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(fn queue ->
      {queue,
       %{
         avail: Map.get(avail_counts, queue, 0),
         execu: Map.get(execu_counts, queue, 0),
         limit: Map.get(total_limits, queue, 0),
         local: Map.get(local_limits, queue, 0),
         pause: Map.get(pause_states, queue, true)
       }}
    end)
  end

  def handle_event("toggle", %{"menu" => "nodes"}, socket) do
    {:noreply, assign(socket, show_nodes?: not socket.assigns.show_nodes?)}
  end

  def handle_event("toggle", %{"menu" => "states"}, socket) do
    {:noreply, assign(socket, show_states?: not socket.assigns.show_states?)}
  end

  def handle_event("toggle", %{"menu" => "queues"}, socket) do
    {:noreply, assign(socket, show_queues?: not socket.assigns.show_queues?)}
  end

  defp payload_limit(%{"global_limit" => limit}), do: limit
  defp payload_limit(%{"local_limit" => limit}), do: limit
  defp payload_limit(%{"limit" => limit}), do: limit
  defp payload_limit(_payload), do: 0
end
