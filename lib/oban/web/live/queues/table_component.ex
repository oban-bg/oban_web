defmodule Oban.Web.Queues.TableComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Components.Sort
  alias Oban.Web.Queues.{ChildRowComponent, GroupRowComponent}

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {sort_by, sort_dir} = atomize_sort(assigns.params)

    queues =
      assigns.checks
      |> Enum.group_by(& &1["queue"])
      |> Enum.sort_by(&table_sort(&1, assigns.counts, sort_by), sort_dir)
      |> queues_to_rows(assigns.counts, assigns.expanded)

    {:ok, assign(socket, access: assigns.access, params: assigns.params, queues: queues)}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <table
      id="queues-table"
      class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700"
    >
      <thead>
        <tr class="text-gray-500 dark:text-gray-400">
          <th
            scope="col"
            class="w-1/4 text-left text-xs font-medium uppercase tracking-wider py-3 pl-4"
          >
            <Sort.header_link
              label="name"
              params={@params}
              socket={@socket}
              page={:queues}
              justify="start"
            />
          </th>
          <th
            scope="col"
            class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1"
          >
            <Sort.header_link
              label="nodes"
              params={@params}
              socket={@socket}
              page={:queues}
              justify="end"
            />
          </th>
          <th
            scope="col"
            class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1"
          >
            <Sort.header_link
              label="exec"
              params={@params}
              socket={@socket}
              page={:queues}
              justify="end"
            />
          </th>
          <th
            scope="col"
            class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1"
          >
            <Sort.header_link
              label="avail"
              params={@params}
              socket={@socket}
              page={:queues}
              justify="end"
            />
          </th>
          <th
            scope="col"
            class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1"
          >
            <Sort.header_link
              label="local"
              params={@params}
              socket={@socket}
              page={:queues}
              justify="end"
            />
          </th>
          <th
            scope="col"
            class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1"
          >
            <Sort.header_link
              label="global"
              params={@params}
              socket={@socket}
              page={:queues}
              justify="end"
            />
          </th>
          <th
            scope="col"
            class="w-24 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1"
          >
            <Sort.header_link
              label="rate limit"
              params={@params}
              socket={@socket}
              page={:queues}
              justify="end"
            />
          </th>
          <th
            scope="col"
            class="w-16 text-right text-xs font-medium uppercase tracking-wider py-3 pl-1"
          >
            <Sort.header_link
              label="started"
              params={@params}
              socket={@socket}
              page={:queues}
              justify="end"
            />
          </th>
          <th scope="col" class="w-5"></th>
        </tr>
      </thead>

      <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
        <%= if Enum.any?(@queues) do %>
          <%= for row_tuple <- @queues do %>
            <%= case row_tuple do %>
              <% {:group, queue, counts, checks, expanded} -> %>
                <.live_component
                  id={queue}
                  module={GroupRowComponent}
                  queue={queue}
                  expanded={expanded}
                  counts={counts}
                  checks={checks}
                  access={@access}
                />
              <% {:child, queue, counts, checks} -> %>
                <.live_component
                  id={"#{checks["queue"]}-#{checks["node"]}"}
                  module={ChildRowComponent}
                  queue={queue}
                  counts={counts}
                  checks={checks}
                  access={@access}
                />
            <% end %>
          <% end %>
        <% else %>
          <tr>
            <td colspan="9" class="text-lg text-center text-gray-500 dark:text-gray-400 py-12">
              <div class="flex items-center justify-center space-x-2">
                <Icons.queue_list /> <span>No active queues.</span>
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
    Enum.flat_map(queues, fn {queue, checks} ->
      avail_count = Map.get(counts, queue, 0)
      expanded? = MapSet.member?(expanded_set, queue)

      group = {:group, queue, avail_count, checks, expanded?}
      children = Enum.map(checks, &{:child, queue, avail_count, &1})

      if expanded? do
        [group | children]
      else
        [group]
      end
    end)
  end

  defp atomize_sort(%{sort_by: sby, sort_dir: dir}) do
    {String.to_existing_atom(sby), String.to_existing_atom(dir)}
  end

  defp table_sort({queue, _checks}, counts, :avail) do
    Map.get(counts, queue, 0)
  end

  defp table_sort({_queue, checks}, _counts, :exec) do
    Enum.reduce(checks, 0, &(length(&1["running"]) + &2))
  end

  defp table_sort({_queue, checks}, _counts, :local) do
    Enum.reduce(checks, 0, &((&1["limit"] || &1["local_limit"]) + &2))
  end

  defp table_sort({_queue, checks}, _counts, :global) do
    total = for %{"local_limit" => limit} <- checks, reduce: 0, do: (acc -> acc + limit)

    Enum.find_value(checks, total, & &1["global_limit"])
  end

  defp table_sort({queue, _checks}, _counts, :name), do: queue

  defp table_sort({_queue, checks}, _counts, :nodes) do
    checks
    |> Enum.uniq_by(& &1["node"])
    |> length()
  end

  defp table_sort({_queue, checks}, _counts, :rate_limit) do
    checks
    |> Enum.map(&get_in(&1, ["rate_limit", "windows"]))
    |> Enum.reject(&is_nil/1)
    |> List.flatten()
    |> Enum.reduce(0, &(&1["curr_count"] + &1["prev_count"] + &2))
  end

  defp table_sort({_queue, checks}, _counts, :started) do
    started_at_to_diff = fn started_at ->
      {:ok, date_time, _} = DateTime.from_iso8601(started_at)

      DateTime.diff(date_time, DateTime.utc_now())
    end

    checks
    |> Enum.map(& &1["started_at"])
    |> Enum.map(started_at_to_diff)
    |> Enum.max()
  end
end
