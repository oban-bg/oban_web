defmodule Oban.Web.Queues.TableComponent do
  use Oban.Web, :live_component

  alias Oban.Web.SortComponent
  alias Oban.Web.Queues.{ChildRowComponent, GroupRowComponent}

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {sort_by, sort_dir} = atomize_sort(assigns.params)

    queues =
      assigns.gossip
      |> Enum.filter(&table_filter(&1, assigns.params.nodes))
      |> Enum.group_by(& &1["queue"])
      |> Enum.sort_by(&table_sort(&1, assigns.counts, sort_by), sort_dir)
      |> queues_to_rows(assigns.counts, assigns.expanded)

    {:ok, assign(socket, access: assigns.access, params: assigns.params, queues: queues)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <table id="queues-table" class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700">
      <thead>
        <tr class="text-gray-500 dark:text-gray-400">
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
          <th scope="col" class="w-5"></th>
        </tr>
      </thead>

      <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
        <%= if Enum.any?(@queues) do %>
          <%= for row_tuple <- @queues do %>
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
        <% else %>
          <tr>
            <td colspan="9" class="text-lg text-center text-gray-500 dark:text-gray-400 py-12">
              <div class="flex items-center justify-center space-x-2">
                <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <span>No queues match the current set of filters.</span>
              </div>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  # Helpers

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

  defp table_filter(_gossip, nil), do: true
  defp table_filter(_gossip, []), do: true
  defp table_filter(gossip, nodes), do: node_name(gossip) in nodes

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
end
