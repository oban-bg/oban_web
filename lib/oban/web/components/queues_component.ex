defmodule Oban.Web.QueuesComponent do
  use Oban.Web, :live_component

  alias Oban.Notifier
  alias Oban.Web.Plugins.Stats
  alias Oban.Web.Queues.{HeaderSortComponent, RowComponent, SidebarComponent}
  alias Oban.Web.Telemetry

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    assigns =
      assigns
      |> Map.take([:access, :conf, :sort_by, :sort_dir])
      |> Map.put_new(:sort_by, :name)
      |> Map.put_new(:sort_dir, :asc)

    counts =
      assigns.conf.name
      |> Stats.all_counts()
      |> Map.new(fn counts -> {counts["name"], counts} end)

    queues =
      assigns.conf.name
      |> Stats.all_gossip()
      |> Enum.group_by(& &1["queue"])
      |> Enum.sort_by(&table_sort(&1, counts, assigns.sort_by), assigns.sort_dir)

    nodes =
      assigns.conf.name
      |> Stats.all_gossip()
      |> Enum.reduce(%{}, &aggregate_nodes/2)
      |> Map.values()
      |> Enum.sort_by(& &1.name)

    socket =
      socket
      |> assign(assigns)
      |> assign(counts: counts, nodes: nodes, queues: queues)

    {:ok, socket}
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
            <tr class="text-gray-400">
              <th scope="col" class="w-1/4 text-left text-xs font-medium uppercase tracking-wider py-3 pl-4">
                <%= live_component HeaderSortComponent, label: "name", by: @sort_by, dir: @sort_dir, justify: "start" %>
              </th>
              <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                <%= live_component HeaderSortComponent, label: "nodes", by: @sort_by, dir: @sort_dir, justify: "end" %>
              </th>
              <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                <%= live_component HeaderSortComponent, label: "exec", by: @sort_by, dir: @sort_dir, justify: "end" %>
              </th>
              <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                <%= live_component HeaderSortComponent, label: "avail", by: @sort_by, dir: @sort_dir, justify: "end" %>
              </th>
              <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                <%= live_component HeaderSortComponent, label: "local", by: @sort_by, dir: @sort_dir, justify: "end" %>
              </th>
              <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                <%= live_component HeaderSortComponent, label: "global", by: @sort_by, dir: @sort_dir, justify: "end" %>
              </th>
              <th scope="col" class="w-24 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                <%= live_component HeaderSortComponent, label: "rate limit", by: @sort_by, dir: @sort_dir, justify: "end" %>
              </th>
              <th scope="col" class="w-16 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                <%= live_component HeaderSortComponent, label: "started", by: @sort_by, dir: @sort_dir, justify: "end" %>
              </th>
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

  # Handlers

  def handle_refresh(socket) do
    socket
  end

  def handle_params(params, _uri, socket) do
    assigns = Keyword.merge([page_title: page_title("Queues")], sort_params(params))

    {:noreply, assign(socket, assigns)}
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

  # Sort Helpers

  defp sort_params(%{"sort" => sort}) do
    [sby, dir] = String.split(sort, "-", parts: 2)

    [sort_by: String.to_existing_atom(sby), sort_dir: String.to_existing_atom(dir)]
  end

  defp sort_params(_params), do: []

  defp table_sort({queue, _gossip}, counts, :avail) do
    get_in(counts, [queue, "available"])
  end

  defp table_sort({_queue, gossip}, _counts, :exec) do
    Enum.reduce(gossip, 0, &(length(&1["running"]) + &2))
  end

  defp table_sort({_queue, gossip}, _counts, :local) do
    Enum.reduce(gossip, 0, &((&1["limit"] || &1["local_limit"]) + &2))
  end

  defp table_sort({_queue, gossip}, _counts, :global) do
    total = for %{"local_limit" => limit} <- gossip, reduce: 0, do: (acc -> acc + limit)

    Enum.find_value(gossip, total, & &1["global_limit"])
  end

  defp table_sort({queue, _gossip}, _counts, :name), do: queue

  defp table_sort({_queue, gossip}, _counts, :nodes) do
    gossip
    |> Enum.uniq_by(& &1["node"])
    |> length()
  end

  defp table_sort({_queue, gossip}, _counts, :rate_limit) do
    gossip
    |> Enum.map(&get_in(&1, ["rate_limit", "windows"]))
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
    |> Enum.reduce(0, &(&1["curr_count"] + &1["prev_count"] + &2))
  end

  defp table_sort({_queue, gossip}, _counts, :started) do
    started_at_to_diff = fn started_at ->
      {:ok, date_time, _} = DateTime.from_iso8601(started_at)

      DateTime.diff(date_time, DateTime.utc_now())
    end

    gossip
    |> Enum.map(& &1["started_at"])
    |> Enum.map(started_at_to_diff)
    |> Enum.max()
  end

  # Helpers

  defp aggregate_nodes(gossip, acc) do
    full_name = node_name(gossip["name"], gossip["node"])
    empty_fun = fn -> %{name: full_name, count: 0, limit: 0} end

    acc
    |> Map.put_new_lazy(full_name, empty_fun)
    |> update_in([full_name, :count], &(&1 + length(gossip["running"])))
    |> update_in([full_name, :limit], &(&1 + (gossip["limit"] || gossip["local_limit"])))
  end
end
