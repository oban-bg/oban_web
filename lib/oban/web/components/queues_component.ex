defmodule Oban.Web.QueuesComponent do
  use Oban.Web, :live_component

  alias Oban.Notifier
  alias Oban.Web.Plugins.Stats
  alias Oban.Web.Queues.{HeaderComponent, RowComponent}
  alias Oban.Web.{Page, SidebarComponent, Telemetry}

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
                  <HeaderComponent.sort_link label="name" params={@params} socket={@socket} justify="start" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <HeaderComponent.sort_link label="nodes" params={@params} socket={@socket} justify="end" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <HeaderComponent.sort_link label="exec" params={@params} socket={@socket} justify="end" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <HeaderComponent.sort_link label="avail" params={@params} socket={@socket} justify="end" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <HeaderComponent.sort_link label="local" params={@params} socket={@socket} justify="end" />
                </th>
                <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <HeaderComponent.sort_link label="global" params={@params} socket={@socket} justify="end" />
                </th>
                <th scope="col" class="w-24 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <HeaderComponent.sort_link label="rate limit" params={@params} socket={@socket} justify="end" />
                </th>
                <th scope="col" class="w-16 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1">
                  <HeaderComponent.sort_link label="started" params={@params} socket={@socket} justify="end" />
                </th>
                <th scope="col" class="w-8"></th>
              </tr>
            </thead>

            <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
              <%= for {queue, gossip} <- @queues do %>
                <.live_component
                  id={queue}
                  module={RowComponent}
                  counts={Map.get(@counts_map, queue, %{})}
                  queue={queue}
                  gossip={gossip}
                  access={@access} />
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
    default = fn -> %{node: nil, sort_by: "name", sort_dir: "asc"} end

    socket
    |> assign_new(:params, default)
    |> assign_new(:default_params, default)
  end

  @impl Page
  def handle_refresh(socket) do
    counts = Stats.all_counts(socket.assigns.conf.name)
    gossip = Stats.all_gossip(socket.assigns.conf.name)

    counts_map = Map.new(counts, &{&1["name"], &1})

    {sort_by, sort_dir} = atomize_sort(socket.assigns.params)

    queues =
      gossip
      |> Enum.filter(&table_filter(&1, socket.assigns.params.node))
      |> Enum.group_by(& &1["queue"])
      |> Enum.sort_by(&table_sort(&1, counts, sort_by), sort_dir)

    assign(socket, counts: counts, counts_map: counts_map, gossip: gossip, queues: queues)
  end

  # Handlers

  @impl Page
  def handle_params(params, _uri, socket) do
    params =
      params
      |> Map.take(["node", "sort_by", "sort_dir"])
      |> Map.new(fn {key, val} -> {String.to_existing_atom(key), val} end)

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
  defp table_filter(gossip, node), do: node_name(gossip) == node

  # Sort Helpers

  defp atomize_sort(%{sort_by: sby, sort_dir: dir}) do
    {String.to_existing_atom(sby), String.to_existing_atom(dir)}
  end

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
end
