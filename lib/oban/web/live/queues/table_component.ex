defmodule Oban.Web.Queues.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers,
    only: [integer_to_delimited: 1, integer_to_estimate: 1, oban_path: 1, oban_path: 2]

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.{Colors, Queue}
  alias Oban.Web.Components.Core

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queues-table" class="min-w-full">
      <Core.table_header>
        <div class="w-16 shrink-0" aria-hidden="true"></div>
        <div class="flex flex-grow items-center min-w-0">
          <Core.column_header label="name" class="flex-1" />
          <div class="ml-auto flex items-center space-x-6">
            <Core.column_header label="utilization" class="w-44" />
            <Core.column_header label="history" class="hidden xl:block w-80 text-center" />
          </div>
        </div>
        <div class="ml-6 pr-3 flex items-center space-x-6">
          <Core.column_header label="available" class="w-20 text-right" />
          <Core.column_header label="scheduled" class="w-20 text-right" />
          <Core.column_header label="retryable" class="w-20 text-right" />
          <Core.column_header label="nodes" class="w-14 text-center" />
          <Core.column_header label="status" class="w-32 text-right" />
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

  # The row link covers the name, utilization, and history. The counts sit outside it so each
  # can be its own link into the jobs list, since anchors can't nest. History is the one column
  # that gives way on narrower desktops, so the name never collapses under the fixed columns.
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
        class="py-5 flex flex-grow items-center min-w-0 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-blue-500"
      >
        <div rel="name" class="flex-1 min-w-0 truncate font-semibold text-gray-700 dark:text-gray-300">
          {@queue.name}
        </div>

        <div class="ml-auto flex items-center space-x-6">
          <% {exec, limit, percent} = utilization(@queue) %>
          <div rel="utilization" class="w-44 flex items-center text-gray-500 dark:text-gray-300">
            <span
              class="flex items-center"
              data-title="Executing / Limit"
              id={"#{@queue.name}-util"}
              phx-hook="Tippy"
            >
              <div class="w-28 h-1.5 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
                <div class="h-full rounded-full bg-emerald-400" style={"width: #{percent}%"} />
              </div>
              <span class="w-14 text-right tabular pl-2">
                <span aria-hidden="true">{exec}/{limit}</span>
                <span class="sr-only">{exec} of {limit} executing</span>
              </span>
            </span>
          </div>

          <div class="hidden xl:flex w-80 justify-center">
            <Core.sparkline
              id={"sparkline-#{@queue.name}"}
              history={@history}
              label={history_label(@history, @total_limit)}
              max_value={@total_limit}
            />
          </div>
        </div>
      </.link>

      <div class="ml-6 pr-3 flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
        <.state_count
          :for={{state, count} <- state_counts(@queue.counts)}
          id={"#{@queue.name}-#{state}"}
          count={count}
          queue={@queue.name}
          state={state}
        />

        <span rel="nodes" class="w-14 text-center">
          {length(@queue.checks)}
          <span class="sr-only">nodes</span>
        </span>

        <div class="w-32 flex justify-end items-center space-x-1">
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
    </li>
    """
  end

  attr :id, :string, required: true
  attr :count, :integer, required: true
  attr :queue, :string, required: true
  attr :state, :string, required: true

  # Each count reads the way a sidebar row does: a dot in the state's hue that dims at zero, then
  # a gray number that fades with it. The header names the state, so the dot never asks for
  # recall, and every count drills into the jobs it counts.
  defp state_count(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={oban_path(:jobs, %{queues: @queue, state: @state})}
      data-title={"#{integer_to_delimited(@count)} #{@state}"}
      phx-hook="Tippy"
      class={[
        "w-20 px-1 py-0.5 -my-0.5 rounded-sm flex items-center justify-end space-x-1.5",
        "hover:bg-gray-100 dark:hover:bg-gray-800",
        "focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500",
        if(@count == 0, do: "text-gray-400 dark:text-gray-600")
      ]}
    >
      <span aria-hidden="true" class={["w-2 h-2 rounded-full", dot_class(@state, @count)]} />
      <span>{integer_to_estimate(@count)}</span>
      <span class="sr-only">{@state}</span>
    </.link>
    """
  end

  attr :icon, :string, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true

  # Limits are configuration rather than a warning, so they lead the status cluster in body gray
  # and leave the amber pause and shutdown glyphs anchored at the right edge.
  defp limit_icon(assigns) do
    ~H"""
    <span
      class="flex items-center text-gray-500 dark:text-gray-400"
      data-title={@label}
      id={@id}
      phx-hook="Tippy"
    >
      <Icons.icon name={@icon} class="w-5 h-5" />
      <span class="sr-only">{@label}</span>
    </span>
    """
  end

  attr :icon, :string, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :rel, :string, required: true

  # Pauses and shutdowns are warnings, so they take the sidebar's amber rather than body ink.
  defp status_icon(assigns) do
    ~H"""
    <span
      class="flex items-center text-amber-500 dark:text-amber-400"
      data-title={@label}
      id={@id}
      phx-hook="Tippy"
    >
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

  # The trace is pointer-only, so its accessible name carries the number a reader would hover for.
  defp history_label(history, limit) do
    peak =
      history
      |> Map.values()
      |> Enum.map(& &1.count)
      |> Enum.max(fn -> 0 end)

    "Recent activity, peak #{peak} of #{limit} executing"
  end

  defp state_counts(counts) do
    for state <- ~w(available scheduled retryable)a do
      {Atom.to_string(state), Map.fetch!(counts, state)}
    end
  end

  defp dot_class(state, count) when count > 0, do: Colors.state_bg_class(state)
  defp dot_class(_state, _count), do: "bg-gray-300 dark:bg-gray-600"
end
