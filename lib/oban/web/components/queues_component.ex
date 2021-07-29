defmodule Oban.Web.QueuesComponent do
  use Oban.Web, :live_component

  alias Oban.Notifier
  alias Oban.Web.Plugins.Stats
  alias Oban.Web.Queues.{RowComponent, SidebarComponent}
  alias Oban.Web.Telemetry

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    counts =
      assigns.conf.name
      |> Stats.all_counts()
      |> Map.new(fn counts -> {counts["name"], counts} end)

    queues =
      assigns.conf.name
      |> Stats.all_gossip()
      |> Enum.group_by(& &1["queue"])
      |> Enum.sort_by(&elem(&1, 0))

    nodes =
      assigns.conf.name
      |> Stats.all_gossip()
      |> Enum.reduce(%{}, &aggregate_nodes/2)
      |> Map.values()
      |> Enum.sort_by(& &1.name)

    {:ok, assign(socket, access: assigns.access, counts: counts, nodes: nodes, queues: queues)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~L"""
    <div id="queues-page" class="w-full flex flex-col my-6 md:flex-row">
      <%= live_component @socket, SidebarComponent, id: :sidebar, nodes: @nodes %>

      <div class="flex-1 bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
        <div id="queues-header" class="flex items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
          <h2 class="text-lg font-bold ml-2">Queues</h2>
          <h3 class="text-lg ml-1 text-gray-500 font-normal tabular">(<%= length(@queues) %>)</h3>
        </div>

        <table id="queues-table" class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead>
            <tr>
              <th scope="col" class="w-1/4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider py-3 pl-9 pr-3">Name</th>
              <th scope="col" class="w-24 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Nodes</th>
              <th scope="col" class="w-12 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Exec</th>
              <th scope="col" class="w-12 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Avail</th>
              <th scope="col" class="w-12 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Local</th>
              <th scope="col" class="w-12 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Global</th>
              <th scope="col" class="w-24 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Rate Limit</th>
              <th scope="col" class="w-16 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Started</th>
              <th scope="col" class="w-8"></th>
            </tr>
          </thead>

          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <%= for {queue, gossip} <- @queues do %>
              <%= live_component @socket,
                RowComponent,
                id: queue,
                counts: Map.get(@counts, queue, %{}),
                queue: queue,
                gossip: gossip,
                access: @access %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  def handle_refresh(socket) do
    socket
  end

  def handle_params(_, _uri, socket) do
    {:noreply, assign(socket, page_title: page_title("Queues"))}
  end

  def handle_info({:pause_queue, queue}, socket) do
    Telemetry.action(:pause_queue, socket, [queue: queue], fn ->
      Oban.pause_queue(socket.assigns.conf.name, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info({:pause_queue, queue, name, node}, socket) do
    Telemetry.action(:pause_queue, socket, [queue: queue, name: name, node: node], fn ->
      # Send the notification ourselves because Oban doesn't currently support custom ident
      # pausing. At this point the name and node are already strings and we can combine the names
      # rather than using Config.to_ident.

      data = %{action: :pause, queue: queue, ident: name <> "." <> node}

      Notifier.notify(socket.assigns.conf, :signal, data)
    end)

    {:noreply, socket}
  end

  def handle_info({:resume_queue, queue}, socket) do
    Telemetry.action(:resume_queue, socket, [queue: queue], fn ->
      Oban.resume_queue(socket.assigns.conf.name, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp aggregate_nodes(gossip, acc) do
    full_name = node_name(gossip["name"], gossip["node"])
    empty_fun = fn -> %{name: full_name, count: 0, limit: 0} end

    acc
    |> Map.put_new_lazy(full_name, empty_fun)
    |> update_in([full_name, :count], &(&1 + length(gossip["running"])))
    |> update_in([full_name, :limit], &(&1 + (gossip["limit"] || gossip["local_limit"])))
  end
end
