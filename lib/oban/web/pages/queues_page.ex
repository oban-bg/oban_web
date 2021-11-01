defmodule Oban.Web.QueuesPage do
  use Oban.Web, :live_component

  alias Oban.Notifier
  alias Oban.Web.Plugins.Stats
  alias Oban.Web.Queues.{ChildRowComponent, GroupRowComponent}
  alias Oban.Web.{Page, SidebarComponent, SortComponent, Telemetry}

  @behaviour Page

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queues-page" class="flex-1 w-full flex flex-col my-6 md:flex-row">
      <.live_component
        id="sidebar"
        module={SidebarComponent}
        sections={[:nodes]}
        counts={@counts}
        gossip={@gossip}
        page={:queues}
        params={without_defaults(@params, @default_params)}
        socket={@socket} />

      <div class="flex-grow">
        <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
          <div id="queues-header" class="flex items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
            <h2 class="text-lg dark:text-gray-200 font-bold ml-2">Queues</h2>
            <h3 class="text-lg ml-1 text-gray-500 font-normal tabular">(<%= length(@queues) %>)</h3>
          </div>

          <table id="queues-table" class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead>
              <tr class="text-gray-400">
                <th scope="col" class="w-1/4 text-left text-xs font-medium uppercase tracking-wider py-3 pl-4">
                  <SortComponent.link label="name" params={@params} socket={@socket} page={:queues} justify="start" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <SortComponent.link label="nodes" params={@params} socket={@socket} page={:queues} justify="end" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <SortComponent.link label="exec" params={@params} socket={@socket} page={:queues} justify="end" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <SortComponent.link label="avail" params={@params} socket={@socket} page={:queues} justify="end" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <SortComponent.link label="local" params={@params} socket={@socket} page={:queues} justify="end" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <SortComponent.link label="global" params={@params} socket={@socket} page={:queues} justify="end" />
                </th>
                <th scope="col" class="w-24 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <SortComponent.link label="rate limit" params={@params} socket={@socket} page={:queues} justify="end" />
                </th>
                <th scope="col" class="w-16 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <SortComponent.link label="started" params={@params} socket={@socket} page={:queues} justify="end" />
                </th>
                <th scope="col" class="w-8"></th>
              </tr>
            </thead>

            <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
              <%= for row_tuple <- queues_to_rows(@queues, @counts, @expanded) do %>
                <%= case row_tuple do %>
                <% {:group, queue, counts, gossip, expanded} -> %>
                  <.live_component
                    id={queue}
                    module={GroupRowComponent}
                    queue={queue}
                    expanded={expanded}
                    counts={counts}
                    gossip={gossip}
                    access={@access} />
                <% {:child, queue, counts, gossip} -> %>
                  <.live_component
                    id={"#{gossip["queue"]}-#{gossip["node"]}"}
                    module={ChildRowComponent}
                    queue={queue}
                    counts={counts}
                    gossip={gossip}
                    access={@access} />
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) do
    default = fn -> %{nodes: nil, sort_by: "name", sort_dir: "asc"} end

    socket
    |> assign_new(:params, default)
    |> assign_new(:default_params, default)
    |> assign_new(:expanded, &MapSet.new/0)
  end

  @impl Page
  def handle_refresh(socket) do
    counts = Stats.all_counts(socket.assigns.conf.name)
    gossip = Stats.all_gossip(socket.assigns.conf.name)

    {sort_by, sort_dir} = atomize_sort(socket.assigns.params)

    queues =
      gossip
      |> Enum.filter(&table_filter(&1, socket.assigns.params.nodes))
      |> Enum.group_by(& &1["queue"])
      |> Enum.sort_by(&table_sort(&1, counts, sort_by), sort_dir)

    assign(socket, counts: counts, gossip: gossip, queues: queues)
  end

  # Handlers

  @impl Page
  def handle_params(params, _uri, socket) do
    params =
      params
      |> Map.take(["nodes", "sort_by", "sort_dir"])
      |> Map.new(fn
        {"nodes", nodes} -> {:nodes, String.split(nodes, ",")}
        {key, val} -> {String.to_existing_atom(key), val}
      end)

    socket =
      socket
      |> assign(page_title: page_title("Queues"))
      |> assign(params: Map.merge(socket.assigns.default_params, params))
      |> handle_refresh()

    {:noreply, socket}
  end

  @impl Page
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

  def handle_info({:toggle_queue, queue}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded, queue) do
        MapSet.delete(socket.assigns.expanded, queue)
      else
        MapSet.put(socket.assigns.expanded, queue)
      end

    {:noreply, assign(socket, expanded: expanded)}
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

  # Filter Helpers

  defp table_filter(_gossip, nil), do: true
  defp table_filter(_gossip, []), do: true
  defp table_filter(gossip, nodes), do: node_name(gossip) in nodes

  # Sort Helpers

  defp atomize_sort(%{sort_by: sby, sort_dir: dir}) do
    {String.to_existing_atom(sby), String.to_existing_atom(dir)}
  end

  defp table_sort({queue, _gossip}, counts, :avail) do
    counts
    |> Enum.find(%{}, &(&1["name"] == queue))
    |> Map.get("available", 0)
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

  # Render Helpers

  defp queues_to_rows(queues, counts, expanded_set) do
    counts_map = Map.new(counts, &{&1["name"], &1})

    Enum.flat_map(queues, fn {queue, gossip} ->
      queue_counts = Map.get(counts_map, queue, %{})
      expanded? = MapSet.member?(expanded_set, queue)

      group = {:group, queue, queue_counts, gossip, expanded?}
      children = Enum.map(gossip, &{:child, queue, queue_counts, &1})

      if expanded? do
        [group | children]
      else
        [group]
      end
    end)
  end
end
