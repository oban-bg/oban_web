defmodule Oban.Web.Queues.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers, only: [integer_to_estimate: 1, oban_path: 1]
  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.Components.Core
  alias Oban.Web.Queue

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queues-table" class="min-w-full">
      <Core.table_header>
        <Core.column_header label="name" class="ml-12 pl-4 w-1/4 text-left" />
        <div class="ml-auto flex items-center space-x-6">
          <Core.column_header label="utilization" class="w-56 pl-4 text-center" />
          <Core.column_header label="history" class="w-80 pl-4 text-center" />
          <Core.column_header label="pending" class="w-42 pl-4 text-center" />
          <Core.column_header label="nodes" class="w-20 pl-4 text-center" />
          <Core.column_header label="status" class="w-20 pl-4 pr-3 text-right" />
        </div>
      </Core.table_header>

      <Core.empty_state
        :if={Enum.empty?(@queues) and Enum.empty?(@checks)}
        icon="icon-queue-list"
        title="No queues"
      >
        Queues process jobs concurrently. They'll appear here once your Oban instance starts with
        queues configured.
        <:actions>
          <Core.learn_link href="https://hexdocs.pm/oban/defining_queues.html">
            Learn about queues
          </Core.learn_link>
        </:actions>
      </Core.empty_state>

      <Core.no_matches
        :if={Enum.empty?(@queues) and not Enum.empty?(@checks)}
        id="queues-no-matches"
        label="No queues match the current filters."
        clear={oban_path(:queues)}
      />

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
        label={"Select queue #{@queue.name}"}
        myself={@myself}
      />

      <.link
        patch={oban_path([:queues, @queue.name])}
        class="py-5 flex flex-grow items-center focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-blue-500"
      >
        <div rel="name" class="w-1/4 font-semibold text-gray-700 dark:text-gray-300">
          {@queue.name}
        </div>

        <div class="ml-auto flex items-center space-x-6">
          <% {exec, limit, percent} = utilization(@queue) %>
          <div rel="utilization" class="w-56 flex items-center text-gray-500 dark:text-gray-300">
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
              <.limit_icon
                :if={Queue.global_limit?(@queue)}
                icon="icon-globe"
                id={"#{@queue.name}-has-global"}
                label="Global limit"
              />
              <.limit_icon
                :if={Queue.rate_limit?(@queue)}
                icon="icon-arrow-trending-down"
                id={"#{@queue.name}-has-rate"}
                label="Rate limit"
              />
              <.limit_icon
                :if={Queue.partitioned?(@queue)}
                icon="icon-view-columns"
                id={"#{@queue.name}-has-partition"}
                label="Partitioned"
              />
            </div>
          </div>

          <div class="w-80 flex justify-center">
            <Core.sparkline
              id={"sparkline-#{@queue.name}"}
              history={@history}
              max_value={@total_limit}
            />
          </div>

          <div
            rel="pending"
            class="w-42 flex items-center justify-end tabular text-gray-500 dark:text-gray-300"
          >
            <.pending_count
              id={"#{@queue.name}-avail"}
              count={@queue.counts.available}
              dot_class="bg-blue-400"
              label="Available"
            />
            <.pending_count
              id={"#{@queue.name}-sched"}
              count={@queue.counts.scheduled}
              dot_class="bg-indigo-400"
              label="Scheduled"
            />
            <.pending_count
              id={"#{@queue.name}-retry"}
              count={@queue.counts.retryable}
              dot_class="bg-yellow-400"
              label="Retryable"
            />
          </div>

          <span rel="nodes" class="w-14 text-center text-gray-500 dark:text-gray-300">
            {length(@queue.checks)}
          </span>

          <div class="w-20 pr-3 flex justify-center items-center space-x-1">
            <.status_icon
              :if={Queue.all_paused?(@queue)}
              icon="icon-pause-circle"
              id={"#{@queue.name}-is-paused"}
              label="All paused"
              rel="is-paused"
            />
            <.status_icon
              :if={Queue.any_paused?(@queue) and not Queue.all_paused?(@queue)}
              icon="icon-play-pause-circle"
              id={"#{@queue.name}-is-some-paused"}
              label="Some paused"
              rel="has-some-paused"
            />
            <.status_icon
              :if={Queue.terminating?(@queue)}
              icon="icon-power"
              id={"#{@queue.name}-is-terminating"}
              label="Terminating"
              rel="terminating"
            />
          </div>
        </div>
      </.link>
    </li>
    """
  end

  attr :id, :string, required: true
  attr :count, :integer, required: true
  attr :dot_class, :string, required: true
  attr :label, :string, required: true

  # An empty bucket keeps its slot but drops to gray, so only queues with waiting jobs draw
  # the eye and the dot color carries the same state meaning as everywhere else.
  defp pending_count(assigns) do
    ~H"""
    <span
      class="w-14 flex items-center space-x-1.5"
      data-title={@label}
      id={@id}
      phx-hook="Tippy"
    >
      <span class="flex-1 text-right">{integer_to_estimate(@count)}</span>
      <span class="sr-only">{@label}</span>
      <span class={[
        "w-2 h-2 rounded-full",
        if(@count > 0, do: @dot_class, else: "bg-gray-300 dark:bg-gray-600")
      ]} />
    </span>
    """
  end

  attr :icon, :string, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true

  defp limit_icon(assigns) do
    ~H"""
    <span class="flex items-center" data-title={@label} id={@id} phx-hook="Tippy">
      <Icons.icon name={@icon} class="w-4 h-4" />
      <span class="sr-only">{@label}</span>
    </span>
    """
  end

  attr :icon, :string, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :rel, :string, required: true

  defp status_icon(assigns) do
    ~H"""
    <span class="flex items-center" data-title={@label} id={@id} phx-hook="Tippy">
      <Icons.icon name={@icon} class="w-5 h-5" rel={@rel} />
      <span class="sr-only">{@label}</span>
    </span>
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
end
