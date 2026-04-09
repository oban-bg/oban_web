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
      <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-500">
        <.queue_header label="name" class="ml-12 w-1/4 text-left" />
        <div class="ml-auto flex items-center space-x-6">
          <.queue_header label="utilization" class="w-56 text-center" />
          <.queue_header label="history" class="w-80 text-center" />
          <.queue_header label="pending" class="w-42 text-center" />
          <.queue_header label="nodes" class="w-20 text-center" />
          <.queue_header label="status" class="w-20 pr-3 text-right" />
        </div>
      </ul>

      <div :if={Enum.empty?(@queues) and Enum.empty?(@checks)} class="py-16 px-6 text-center">
        <Icons.icon name="icon-queue-list" class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" />
        <h3 class="mt-4 text-xl font-semibold text-gray-900 dark:text-gray-100">No queues</h3>
        <p class="mt-2 text-base text-gray-500 dark:text-gray-400 max-w-md mx-auto">
          Queues process jobs concurrently. They'll appear here once your Oban instance starts with queues configured.
        </p>
        <div class="mt-4">
          <a
            href="https://hexdocs.pm/oban/defining_queues.html"
            target="_blank"
            rel="noopener"
            class="text-base font-medium text-violet-600 hover:text-violet-500 dark:text-violet-400 dark:hover:text-violet-300"
          >
            Learn about queues <span aria-hidden="true">&rarr;</span>
          </a>
        </div>
      </div>

      <div
        :if={Enum.empty?(@queues) and not Enum.empty?(@checks)}
        class="flex items-center justify-center py-12 space-x-2 text-lg text-gray-600 dark:text-gray-300"
      >
        <Icons.icon name="icon-no-symbol" /> <span>No queues match the current filters.</span>
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
              <Icons.icon
                :if={Queue.global_limit?(@queue)}
                name="icon-globe"
                class="w-4 h-4"
                data-title="Global limit"
                id={"#{@queue.name}-has-global"}
                phx-hook="Tippy"
              />
              <Icons.icon
                :if={Queue.rate_limit?(@queue)}
                name="icon-arrow-trending-down"
                class="w-4 h-4"
                data-title="Rate limit"
                id={"#{@queue.name}-has-rate"}
                phx-hook="Tippy"
              />
              <Icons.icon
                :if={Queue.partitioned?(@queue)}
                name="icon-view-columns"
                class="w-4 h-4"
                data-title="Partitioned"
                id={"#{@queue.name}-has-partition"}
                phx-hook="Tippy"
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
            <span
              class="w-14 flex items-center space-x-1.5"
              data-title="Available"
              id={"#{@queue.name}-avail"}
              phx-hook="Tippy"
            >
              <span class="flex-1 text-right">{integer_to_estimate(@queue.counts.available)}</span>
              <span class={[
                "w-2 h-2 rounded-full",
                if(@queue.counts.available > 0,
                  do: "bg-cyan-400",
                  else: "bg-gray-300 dark:bg-gray-600"
                )
              ]} />
            </span>
            <span
              class="w-14 flex items-center space-x-1.5"
              data-title="Scheduled"
              id={"#{@queue.name}-sched"}
              phx-hook="Tippy"
            >
              <span class="flex-1 text-right">{integer_to_estimate(@queue.counts.scheduled)}</span>
              <span class={[
                "w-2 h-2 rounded-full",
                if(@queue.counts.scheduled > 0,
                  do: "bg-emerald-400",
                  else: "bg-gray-300 dark:bg-gray-600"
                )
              ]} />
            </span>
            <span
              class="w-14 flex items-center space-x-1.5"
              data-title="Retryable"
              id={"#{@queue.name}-retry"}
              phx-hook="Tippy"
            >
              <span class="flex-1 text-right">{integer_to_estimate(@queue.counts.retryable)}</span>
              <span class={[
                "w-2 h-2 rounded-full",
                if(@queue.counts.retryable > 0,
                  do: "bg-yellow-400",
                  else: "bg-gray-300 dark:bg-gray-600"
                )
              ]} />
            </span>
          </div>

          <span rel="nodes" class="w-14 text-center text-gray-500 dark:text-gray-300">
            {length(@queue.checks)}
          </span>

          <div class="w-20 pr-3 flex justify-center items-center space-x-1">
            <Icons.icon
              :if={Queue.all_paused?(@queue)}
              name="icon-pause-circle"
              class="w-5 h-5"
              data-title="All paused"
              id={"#{@queue.name}-is-paused"}
              phx-hook="Tippy"
              rel="is-paused"
            />
            <Icons.icon
              :if={Queue.any_paused?(@queue) and not Queue.all_paused?(@queue)}
              name="icon-play-pause-circle"
              class="w-5 h-5"
              data-title="Some paused"
              id={"#{@queue.name}-is-some-paused"}
              phx-hook="Tippy"
              rel="has-some-paused"
            />
            <Icons.icon
              :if={Queue.terminating?(@queue)}
              name="icon-power"
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
end
