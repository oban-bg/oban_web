defmodule Oban.Web.Queues.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.Queue

  @sparkline_count 60
  @sparkline_height 16
  @sparkline_bar_width 4
  @sparkline_gap 1

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queues-table" class="min-w-full">
      <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-500">
        <.queue_header label="name" class="ml-12 w-1/4 text-left" />
        <div class="ml-auto flex items-center space-x-6">
          <.queue_header label="utilization" class="w-56 text-center" />
          <.queue_header label="history" class="w-80 text-center" />
          <.queue_header label="pending" class="w-42 text-center" />
          <.queue_header label="nodes" class="w-14 text-center" />
          <.queue_header label="started" class="w-28 text-right" />
          <.queue_header label="status" class="w-20 pr-3 text-right" />
        </div>
      </ul>

      <div
        :if={Enum.empty?(@queues)}
        class="flex items-center justify-center py-12 space-x-2 text-lg text-gray-600 dark:text-gray-300"
      >
        <Icons.no_symbol /> <span>No queues running match the current set of filters.</span>
      </div>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.queue_row
          :for={queue <- @queues}
          access={@access}
          history={Map.get(@history, queue.name, %{})}
          myself={@myself}
          queue={queue}
          selected={MapSet.member?(@selected, queue.name)}
          total_limit={Queue.local_limit(queue)}
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
      {@label}
    </span>
    """
  end

  attr :history, :map, required: true
  attr :id, :string, required: true
  attr :total_limit, :integer, required: true

  defp queue_sparkline(assigns) do
    history = assigns.history
    total_limit = max(assigns.total_limit, 1)
    now = System.system_time(:millisecond)
    max_index = @sparkline_count - 1

    {bars, tooltip_data} =
      for slot <- 0..max_index, reduce: {[], []} do
        {bars_acc, tool_acc} ->
          index = max_index - slot
          timestamp = now - index * 5 * 1000
          x = slot * (@sparkline_bar_width + @sparkline_gap)

          case Map.get(history, index) do
            %{count: count} ->
              height = min(count / total_limit, 1.0) * @sparkline_height
              bar = %{x: x, height: max(height, 0)}
              tooltip = %{timestamp: timestamp, count: count}

              {[bar | bars_acc], [tooltip | tool_acc]}

            nil ->
              tooltip = %{timestamp: timestamp, count: 0}

              {bars_acc, [tooltip | tool_acc]}
          end
      end

    bars = Enum.reverse(bars)
    tooltip_data = Enum.reverse(tooltip_data)

    placeholders =
      for slot <- 0..max_index do
        %{x: slot * (@sparkline_bar_width + @sparkline_gap)}
      end

    width = @sparkline_count * (@sparkline_bar_width + @sparkline_gap)

    assigns =
      assigns
      |> assign(bars: bars, placeholders: placeholders, width: width)
      |> assign(height: @sparkline_height, bar_width: @sparkline_bar_width)
      |> assign(tooltip_data: tooltip_data)

    ~H"""
    <svg
      id={@id}
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      class="flex-shrink-0 cursor-pointer"
      phx-hook="QueueSparkline"
      data-tooltip={Oban.JSON.encode!(@tooltip_data)}
      data-bar-width={@bar_width}
    >
      <rect
        :for={placeholder <- @placeholders}
        x={placeholder.x}
        y={@height - 2}
        width={@bar_width}
        height="2"
        fill="#e5e7eb"
        class="dark:fill-gray-700"
        rx="0.5"
      />
      <rect
        :for={bar <- @bars}
        x={bar.x}
        y={@height - bar.height}
        width={@bar_width}
        height={bar.height}
        fill="#22d3ee"
        rx="1"
      />
    </svg>
    """
  end

  attr :access, :map, required: true
  attr :history, :map, required: true
  attr :myself, :any, required: true
  attr :queue, :string, required: true
  attr :selected, :boolean, default: false
  attr :total_limit, :integer, required: true

  defp queue_row(assigns) do
    ~H"""
    <li
      id={"queue-#{@queue.name}"}
      class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30"
    >
      <Core.row_checkbox
        click="toggle-select"
        value={@queue.name}
        checked={@selected}
        myself={@myself}
      />

      <.link patch={oban_path([:queues, @queue.name])} class="py-5 flex flex-grow items-center">
        <div rel="name" class="w-1/4 font-semibold text-gray-700 dark:text-gray-300">
          {@queue.name}
        </div>

        <% {exec, limit, percent} = utilization(@queue) %>
        <div rel="utilization" class="w-56 flex items-center px-6 text-gray-500 dark:text-gray-300">
          <span
            class="flex items-center"
            data-title="Executing / Limit"
            id={"#{@queue.name}-util"}
            phx-hook="Tippy"
          >
            <div class="w-28 h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
              <div class="h-full rounded-full bg-emerald-400" style={"width: #{percent}%"} />
            </div>
            <span class="w-14 text-left tabular pl-2">{exec}/{limit}</span>
          </span>
          <div class="w-14 flex items-center justify-start space-x-1 text-gray-400 dark:text-gray-500">
              <Icons.globe
                :if={Queue.global_limit?(@queue)}
                class="w-4 h-4"
                data-title="Global limit"
                id={"#{@queue.name}-has-global"}
                phx-hook="Tippy"
              />
              <Icons.arrow_trending_down
                :if={Queue.rate_limit?(@queue)}
                class="w-4 h-4"
                data-title="Rate limit"
                id={"#{@queue.name}-has-rate"}
                phx-hook="Tippy"
              />
              <Icons.view_columns
                :if={Queue.partitioned?(@queue)}
                class="w-4 h-4"
                data-title="Partitioned"
                id={"#{@queue.name}-has-partition"}
                phx-hook="Tippy"
              />
            </div>
        </div>

        <div class="w-80 flex justify-center">
          <.queue_sparkline id={"sparkline-#{@queue.name}"} history={@history} total_limit={@total_limit} />
        </div>

        <div class="flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <div rel="pending" class="w-42 flex items-center justify-end">
            <span class="w-14 flex items-center space-x-1.5" data-title="Available" id={"#{@queue.name}-avail"} phx-hook="Tippy">
              <span class="flex-1 text-right">{integer_to_estimate(@queue.counts.available)}</span>
              <span class={["w-2 h-2 rounded-full", if(@queue.counts.available > 0, do: "bg-cyan-400", else: "bg-gray-300 dark:bg-gray-600")]} />
            </span>
            <span class="w-14 flex items-center space-x-1.5" data-title="Scheduled" id={"#{@queue.name}-sched"} phx-hook="Tippy">
              <span class="flex-1 text-right">{integer_to_estimate(@queue.counts.scheduled)}</span>
              <span class={["w-2 h-2 rounded-full", if(@queue.counts.scheduled > 0, do: "bg-emerald-400", else: "bg-gray-300 dark:bg-gray-600")]} />
            </span>
            <span class="w-14 flex items-center space-x-1.5" data-title="Retryable" id={"#{@queue.name}-retry"} phx-hook="Tippy">
              <span class="flex-1 text-right">{integer_to_estimate(@queue.counts.retryable)}</span>
              <span class={["w-2 h-2 rounded-full", if(@queue.counts.retryable > 0, do: "bg-yellow-400", else: "bg-gray-300 dark:bg-gray-600")]} />
            </span>
          </div>

          <span rel="nodes" class="w-14 text-center">
            {length(@queue.checks)}
          </span>

          <span
            rel="started"
            class="w-28 text-right"
            id={"#{@queue.name}-started"}
            data-timestamp={started_at_unix(@queue)}
            phx-hook="Relativize"
            phx-update="ignore"
          >
            {started_at(@queue)}
          </span>

          <div class="w-20 pr-3 flex justify-center items-center space-x-1">
            <Icons.pause_circle
              :if={Queue.all_paused?(@queue)}
              class="w-5 h-5"
              data-title="All paused"
              id={"#{@queue.name}-is-paused"}
              phx-hook="Tippy"
              rel="is-paused"
            />
            <Icons.play_pause_circle
              :if={Queue.any_paused?(@queue) and not Queue.all_paused?(@queue)}
              class="w-5 h-5"
              data-title="Some paused"
              id={"#{@queue.name}-is-some-paused"}
              phx-hook="Tippy"
              rel="has-some-paused"
            />
            <Icons.power
              :if={Queue.terminating?(@queue)}
              class="w-5 h-5"
              data-title="Terminating"
              id={"#{@queue.name}-is-terminating"}
              phx-hook="Tippy"
              rel="terminating"
            />
          </div>
        </div>
      </.link>
    </li>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("toggle-select", %{"id" => queue}, socket) do
    send(self(), {:toggle_select, queue})

    {:noreply, socket}
  end

  # Helpers

  defp utilization(queue) do
    exec = executing_count(queue.checks)
    limit = Queue.local_limit(queue)
    percent = if limit > 0, do: min(round(exec / limit * 100), 100), else: 0
    {exec, limit, percent}
  end

  defp started_at_unix(queue) do
    queue.checks
    |> Enum.map(& &1["started_at"])
    |> Enum.map(&iso_to_unix/1)
    |> Enum.min()
  end

  defp iso_to_unix(iso_string) do
    {:ok, dt, _} = DateTime.from_iso8601(iso_string)
    DateTime.to_unix(dt, :millisecond)
  end
end
