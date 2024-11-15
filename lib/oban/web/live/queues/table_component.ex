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
    <div id="queues-table" class="min-w-full">
      <ul class="flex items-center border-b border-gray-200 text-gray-400 dark:text-gray-600">
        <.queue_header label="name" class="ml-12 w-1/3 text-left" />
        <div class="ml-auto flex items-center space-x-6">
          <.queue_header label="nodes" class="w-16 text-right" />
          <.queue_header label="exec" class="w-16 text-right" />
          <.queue_header label="avail" class="w-16 text-right" />
          <.queue_header label="local" class="w-16 text-right" />
          <.queue_header label="global" class="w-16 text-right" />
          <.queue_header label="rate limit" class="w-32 text-right" />
          <.queue_header label="started" class="w-20 text-right" />
          <.queue_header label="pause" class="w-20 pr-6 text-right" />
        </div>
      </ul>

      <div :if={Enum.empty?(@queues)} class="flex items-center justify-center space-x-2">
        <Icons.queue_list /> <span>No queues are currently running.</span>
      </div>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.queue_row
          :for={{queue, counts, checks} <- @queues}
          access={@access}
          checks={checks}
          counts={counts}
          myself={@myself}
          queue={queue}
        />
      </ul>
    </div>
    """
  end

  # Components

  attr :label, :string, required: true
  attr :class, :string, default: ""

  defp queue_header(assigns) do
    ~H"""
    <span class={[@class, "text-xs font-medium uppercase tracking-wider py-1.5 pl-4"]}>
      <%= @label %>
    </span>
    """
  end

  attr :access, :map, required: true
  attr :checks, :map, required: true
  attr :counts, :map, required: true
  attr :myself, :any, required: true
  attr :queue, :string, required: true

  defp queue_row(assigns) do
    ~H"""
    <li id={"queue-#{@queue}"} class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30">
      <button class="p-6 group" phx-click="toggle-select" phx-value-id={@queue}>
        <div class="w-4 h-4 border border-2 border-gray-400 rounded group-hover:bg-gray-400">
          <Icons.check class="w-3 h-3 text-white hover:text-white" />
        </div>
      </button>

      <.link
        patch={oban_path([:queues, @queue])}
        class="py-3 flex flex-grow items-center"
      >
        <div rel="name" class="py-3 w-1/3 font-semibold text-gray-700 dark:text-gray-300">
          <%= @queue %>
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <span rel="nodes" class="w-16 text-right">
            <%= nodes_count(@checks) %>
          </span>

          <span rel="executing" class="w-16 text-right">
            <%= executing_count(@checks) %>
          </span>

          <span rel="available" class="w-16 text-right">
            <%= integer_to_estimate(@counts) %>
          </span>

          <span rel="local" class="w-16 text-right">
            <%= local_limit(@checks) %>
          </span>

          <span rel="global" class="w-16 text-right">
            <%= global_limit_to_words(@checks) %>
          </span>

          <span rel="rate" class="w-32 text-right">
            <%= rate_limit_to_words(@checks) %>
          </span>

          <span rel="started" class="w-20 text-right">
            <%= started_at(@checks) %>
          </span>

          <span class="w-20 pr-6 flex justify-end border-r border-transparent">
            <Core.pause_button
              click="toggle-pause"
              disabled={not can?(:pause_queues, @access)}
              queue={@queue}
              target={@myself}
              paused={any_paused?(@checks)}
              title={pause_title(@checks)}
            />
          </span>
        </div>
      </.link>
    </li>
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
