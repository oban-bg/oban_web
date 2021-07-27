defmodule Oban.Web.QueuesComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Plugins.Stats
  alias Oban.Web.Queues.RowComponent
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
      |> Enum.reduce(%{}, &aggregate(&1, counts, &2))
      |> Map.values()
      |> Enum.sort_by(& &1.queue)

    {:ok, assign(socket, access: assigns.access, queues: queues)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~L"""
    <div id="queues-page" class="w-full my-6 md:flex-row">
      <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
        <div id="queues-header" class="flex items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
          <h2 class="text-lg font-bold ml-2">Queues</h2>
          <h3 class="text-lg ml-1 text-gray-500 font-normal tabular">(<%= length(@queues) %>)</h3>
        </div>

        <table id="queues-table" class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead>
            <tr>
              <th scope="col" class="w-1/4 text-left text-xs font-medium text-gray-400 uppercase tracking-wider py-3 pl-9 pr-3">Name</th>
              <th scope="col" class="w-12 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Nodes</th>
              <th scope="col" class="w-16 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Executing</th>
              <th scope="col" class="w-16 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Available</th>
              <th scope="col" class="w-16 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Completed</th>
              <th scope="col" class="w-16 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Local</th>
              <th scope="col" class="w-16 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Global</th>
              <th scope="col" class="w-24 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Rate</th>
              <th scope="col" class="w-16 text-right text-xs font-medium text-gray-400 uppercase tracking-wider py-3 px-1">Started</th>
              <th scope="col" class="w-8"></th>
            </tr>
          </thead>

          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <%= for queue <- @queues do %>
              <%= live_component @socket, RowComponent, id: queue.id, queue: queue, access: @access %>
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

  def handle_info({:resume_queue, queue}, socket) do
    Telemetry.action(:resume_queue, socket, [queue: queue], fn ->
      Oban.resume_queue(socket.assigns.conf.name, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  defp aggregate(%{"queue" => queue} = gossip, counts, acc) do
    empty_fun = fn ->
      id = Enum.join([gossip["node"], gossip["name"], gossip["queue"]], "-")

      %{
        id: id,
        queue: queue,
        executing: 0,
        available: get_in(counts, [queue, "available"]) || 0,
        completed: get_in(counts, [queue, "completed"]) || 0,
        local_limits: [],
        global_limits: [],
        rate_limits: [],
        pauses: [],
        nodes: MapSet.new(),
        uptime: 0
      }
    end

    acc
    |> Map.put_new_lazy(queue, empty_fun)
    |> update_in([queue, :pauses], &[gossip["paused"] | &1])
    |> update_in([queue, :global_limits], &[gossip["global_limit"] | &1])
    |> update_in([queue, :local_limits], &[gossip["local_limit"] | &1])
    |> update_in([queue, :rate_limits], &[gossip["rate_limit"] | &1])
    |> update_in([queue, :nodes], &MapSet.put(&1, gossip["node"]))
    |> update_in([queue, :executing], &(&1 + length(gossip["running"])))
    |> update_in([queue, :uptime], &started_to_uptime(&1, gossip["started_at"]))
  end

  defp started_to_uptime(prev_uptime, started_at) do
    {:ok, date_time, _} = DateTime.from_iso8601(started_at)

    this_uptime = DateTime.diff(date_time, DateTime.utc_now())

    if this_uptime < prev_uptime, do: this_uptime, else: prev_uptime
  end
end
