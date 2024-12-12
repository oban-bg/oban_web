defmodule Oban.Web.Queues.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queues-table" class="min-w-full">
      <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-600">
        <.queue_header label="name" class="ml-12 w-1/3 text-left" />
        <div class="ml-auto flex items-center space-x-6">
          <.queue_header label="nodes" class="w-16 text-right" />
          <.queue_header label="exec" class="w-16 text-right" />
          <.queue_header label="avail" class="w-16 text-right" />
          <.queue_header label="local" class="w-16 text-right" />
          <.queue_header label="global" class="w-16 text-right" />
          <.queue_header label="rate limit" class="w-32 text-right" />
          <.queue_header label="started" class="w-28 text-right" />
          <.queue_header label="statuses" class="w-28 pr-6 text-right" />
        </div>
      </ul>

      <div
        :if={Enum.empty?(@queues)}
        class="flex items-center justify-center py-12 space-x-2 text-lg text-gray-600 dark:text-gray-300"
      >
        <Icons.queue_list /> <span>No queues are currently running.</span>
      </div>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.queue_row
          :for={queue <- @queues}
          access={@access}
          myself={@myself}
          queue={queue}
          selected={MapSet.member?(@selected, queue.name)}
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
  attr :myself, :any, required: true
  attr :queue, :string, required: true
  attr :selected, :boolean, default: false

  defp queue_row(assigns) do
    ~H"""
    <li id={"queue-#{@queue.name}"} class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30">
      <Core.row_checkbox click="toggle-select" value={@queue.name} checked={@selected} myself={@myself} />

      <.link patch={oban_path([:queues, @queue.name])} class="py-5 flex flex-grow items-center">
        <div rel="name" class="w-1/3 font-semibold text-gray-700 dark:text-gray-300">
          {@queue.name}
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <span rel="nodes" class="w-16 text-right">
            {nodes_count(@queue.checks)}
          </span>

          <span rel="executing" class="w-16 text-right">
            {executing_count(@queue.checks)}
          </span>

          <span rel="available" class="w-16 text-right">
            {integer_to_estimate(@queue.counts)}
          </span>

          <span rel="local" class="w-16 text-right">
            {local_limit(@queue.checks)}
          </span>

          <span rel="global" class="w-16 text-right">
            {global_limit_to_words(@queue.checks)}
          </span>

          <span rel="rate" class="w-32 text-right">
            {rate_limit_to_words(@queue.checks)}
          </span>

          <span rel="started" class="w-28 text-right">
            {started_at(@queue.checks)}
          </span>

          <div class="w-28 pr-6 flex justify-end items-center space-x-1">
            <Icons.arrow_trending_down
              :if={rate_limited?(@queue.checks)}
              class="w-4 h-4"
              data-title="Rate limited"
              id={"#{@queue.name}-is-rate-limited"}
              phx-hook="Tippy"
              rel="is-rate-limited"
            />
            <Icons.globe
              :if={global?(@queue.checks)}
              class="w-4 h-4"
              data-title="Globally limited"
              id={"#{@queue.name}-is-global"}
              phx-hook="Tippy"
              rel="is-global"
            />
            <Icons.pause_circle
              :if={all_paused?(@queue.checks)}
              class="w-4 h-4"
              data-title="All paused"
              id={"#{@queue.name}-is-paused"}
              phx-hook="Tippy"
              rel="is-paused"
            />
            <Icons.play_pause_circle
              :if={any_paused?(@queue.checks) and not all_paused?(@queue.checks)}
              class="w-4 h-4"
              data-title="Some paused"
              id={"#{@queue.name}-is-some-paused"}
              phx-hook="Tippy"
              rel="has-some-paused"
            />
            <Icons.power
              :if={shutting_down?(@queue.checks)}
              class="w-4 h-4"
              data-title="Shutting down"
              id={"#{@queue.name}-is-shutting-down"}
              phx-hook="Tippy"
              rel="shutting-down"
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

  defp all_paused?(checks), do: Enum.all?(checks, & &1["paused"])

  defp global?(checks), do: Enum.any?(checks, &is_map(&1["global_limit"]))

  defp rate_limited?(checks), do: Enum.any?(checks, &is_map(&1["rate_limit"]))

  defp shutting_down?(checks), do: Enum.any?(checks, & &1["shutdown_started_at"])
end
