defmodule Oban.Web.Queues.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.QueueHelper

  alias Oban.Web.{Queue, Timing}

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
        <div rel="name" class="w-1/3 font-semibold text-gray-700 dark:text-gray-300">
          {@queue.name}
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <span rel="nodes" class="w-16 text-right">
            {length(@queue.checks)}
          </span>

          <span rel="executing" class="w-16 text-right">
            {@queue.counts.executing}
          </span>

          <span rel="available" class="w-16 text-right">
            {integer_to_estimate(@queue.counts.available)}
          </span>

          <span rel="local" class="w-16 text-right">
            {local_limit(@queue)}
          </span>

          <span rel="global" class="w-16 text-right">
            {global_limit(@queue)}
          </span>

          <span rel="rate" class="w-32 text-right">
            {rate_limit(@queue)}
          </span>

          <span rel="started" class="w-28 text-right">
            {started_at(@queue)}
          </span>

          <div class="w-20 pr-3 flex justify-end items-center space-x-1">
            <Icons.pause_circle
              :if={Queue.all_paused?(@queue)}
              class="w-4 h-4"
              data-title="All paused"
              id={"#{@queue.name}-is-paused"}
              phx-hook="Tippy"
              rel="is-paused"
            />
            <Icons.play_pause_circle
              :if={Queue.any_paused?(@queue) and not Queue.all_paused?(@queue)}
              class="w-4 h-4"
              data-title="Some paused"
              id={"#{@queue.name}-is-some-paused"}
              phx-hook="Tippy"
              rel="has-some-paused"
            />
            <Icons.power
              :if={Queue.terminating?(@queue)}
              class="w-4 h-4"
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

  defp local_limit(queue) do
    queue.checks
    |> Enum.map(& &1["local_limit"])
    |> Enum.min_max()
    |> case do
      {min, min} -> min
      {min, max} -> "#{min}..#{max}"
    end
  end

  defp global_limit(queue) do
    Queue.global_limit(queue) || "-"
  end

  defp rate_limit(queue) do
    queue.checks
    |> Enum.map(& &1["rate_limit"])
    |> Enum.reject(&is_nil/1)
    |> case do
      [head_limit | _rest] = rate_limits ->
        %{"allowed" => allowed, "period" => period, "window_time" => time} = head_limit

        {prev_total, curr_total} =
          rate_limits
          |> Enum.flat_map(& &1["windows"])
          |> Enum.reduce({0, 0}, fn %{"prev_count" => pcnt, "curr_count" => ccnt}, {pacc, cacc} ->
            {pacc + pcnt, cacc + ccnt}
          end)

        unix_now = DateTime.to_unix(DateTime.utc_now(), :second)
        ellapsed = unix_now - time_to_unix(time)
        weight = div(max(period - ellapsed, 0), period)
        remaining = prev_total * weight + curr_total

        period_in_words = Timing.to_words(period, relative: false)

        "#{remaining}/#{allowed} per #{period_in_words}"

      [] ->
        "-"
    end
  end

  defp time_to_unix(unix) when is_integer(unix), do: unix

  defp time_to_unix(time) do
    Date.utc_today()
    |> DateTime.new!(Time.from_iso8601!(time))
    |> DateTime.to_unix(:second)
  end
end
