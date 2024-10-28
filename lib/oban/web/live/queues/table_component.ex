defmodule Oban.Web.Queues.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.Components.Core

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    {sort_by, sort_dir} = atomize_sort(assigns.params)

    queues =
      assigns.checks
      |> Enum.group_by(& &1["queue"])
      |> Enum.sort_by(&table_sort(&1, assigns.counts, sort_by), sort_dir)
      |> queues_to_rows(assigns.counts)

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
        <tr class="text-gray-400 dark:text-gray-600">
          <.th label="name" class="w-1/4 text-left" />
          <.th label="nodes" class="w-16 text-right" />
          <.th label="exec" class="w-16 text-right" />
          <.th label="avail" class="w-12 text-right" />
          <.th label="local" class="w-12 text-right" />
          <.th label="global" class="w-12 text-right" />
          <.th label="rate limit" class="w-24 text-right" />
          <.th label="started" class="w-16 text-right" />
          <.th label="pause" class="w-4 pr-4 text-right" />
        </tr>
      </thead>

      <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
        <%= if Enum.any?(@queues) do %>
          <.queue_row
            :for={{queue, counts, checks} <- @queues}
            access={@access}
            checks={checks}
            counts={counts}
            myself={@myself}
            queue={queue}
          />
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

  # Components

  attr :label, :string, required: true
  attr :class, :string, default: ""

  defp th(assigns) do
    ~H"""
    <th scope="col" class={[@class, "text-xs font-medium uppercase tracking-wider py-1.5 pl-4"]}>
      <%= @label %>
    </th>
    """
  end

  attr :access, :any, required: true
  attr :checks, :map, required: true
  attr :counts, :map, required: true
  attr :myself, :any, required: true
  attr :queue, :string, required: true

  defp queue_row(assigns) do
    ~H"""
    <tr
      id={"queue-#{@queue}"}
      class="bg-white dark:bg-gray-900 hover:bg-gray-50 dark:hover:bg-gray-950/30"
    >
      <td class="pl-4 py-3 text-gray-700 dark:text-gray-300 flex items-center space-x-2">
        <.link
          patch={oban_path([:queues, @queue])}
          data-title={"View and configure #{@queue} details"}
          class="block font-semibold text-blue-600 dark:text-blue-300 hover:text-blue-700 dark:hover:text-blue-400"
          phx-hook="Tippy"
          rel="name"
        >
          <%= @queue %>
        </.link>
      </td>

      <td rel="nodes" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= nodes_count(@checks) %>
      </td>

      <td rel="executing" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= executing_count(@checks) %>
      </td>

      <td rel="available" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= integer_to_estimate(@counts) %>
      </td>

      <td rel="local" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= local_limit(@checks) %>
      </td>

      <td rel="global" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= global_limit_to_words(@checks) %>
      </td>

      <td rel="rate" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= rate_limit_to_words(@checks) %>
      </td>

      <td rel="started" class="py-3 pl-3 text-right text-gray-500 dark:text-gray-300 tabular">
        <%= started_at(@checks) %>
      </td>

      <td class="py-3 pr-6 flex justify-end border-r border-transparent">
        <Core.pause_button
          click="toggle-pause"
          disabled={not can?(:pause_queues, @access)}
          queue={@queue}
          target={@myself}
          paused={any_paused?(@checks)}
          title={pause_title(@checks)}
        />
      </td>
    </tr>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("toggle-pause", %{"queue" => queue}, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    with {_queue, _avail, checks} <- Enum.find(socket.assigns.queues, &(elem(&1, 0) == queue)) do
      action = if any_paused?(checks), do: :resume_queue, else: :pause_queue

      send(self(), {action, queue})
    end

    {:noreply, socket}
  end

  # Helpers

  defp queues_to_rows(queues, counts) do
    Enum.map(queues, fn {queue, checks} ->
      avail_count = Map.get(counts, queue, 0)

      {queue, avail_count, checks}
    end)
  end

  defp pause_title(checks) do
    cond do
      Enum.all?(checks, & &1["paused"]) -> "Resume all instances"
      Enum.any?(checks, & &1["paused"]) -> "Resume paused instances"
      true -> "Pause all instances"
    end
  end

  defp nodes_count(checks), do: length(checks)

  defp local_limit(checks) do
    checks
    |> Enum.map(& &1["local_limit"])
    |> Enum.min_max()
    |> case do
      {min, min} -> min
      {min, max} -> "#{min}..#{max}"
    end
  end

  defp any_paused?(checks), do: Enum.any?(checks, & &1["paused"])

  # Sorting

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
