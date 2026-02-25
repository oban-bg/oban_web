defmodule Oban.Web.Crons.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Crons.Helpers, only: [maybe_to_unix: 1, show_name?: 1, state_icon: 1]

  alias Oban.Web.Cron

  @sparkline_count 60
  @sparkline_height 16
  @sparkline_bar_width 4
  @sparkline_gap 1

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="crons-table" class="min-w-full">
      <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-500">
        <.header label="name" class="pl-3 w-1/3 text-left" />
        <div class="ml-auto flex items-center space-x-6">
          <.header label="history" class="w-80 text-center" />
          <.header label="schedule" class="w-32 text-right" />
          <.header label="last run" class="w-32 text-right" />
          <.header label="next run" class="w-32 text-right" />
          <.header label="status" class="w-20 pr-4 text-right" />
        </div>
      </ul>

      <div :if={Enum.empty?(@crontab)} class="py-16 px-6 text-center">
        <Icons.clock class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" />
        <h3 class="mt-4 text-xl font-semibold text-gray-900 dark:text-gray-100">No crons</h3>
        <p class="mt-2 text-base text-gray-500 dark:text-gray-400 max-w-md mx-auto">
          Crons run jobs on a schedule. Configure them in your Oban supervisor or create them dynamically.
        </p>
        <div class="mt-4">
          <a
            href="https://hexdocs.pm/oban/periodic_jobs.html"
            target="_blank"
            rel="noopener"
            class="text-base font-medium text-violet-600 hover:text-violet-500 dark:text-violet-400 dark:hover:text-violet-300"
          >
            Learn about crons <span aria-hidden="true">&rarr;</span>
          </a>
        </div>
      </div>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.cron_row :for={cron <- @crontab} id={cron.name} cron={cron} />
      </ul>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :class, :string, default: ""

  defp header(assigns) do
    ~H"""
    <span class={[@class, "text-xs font-medium uppercase tracking-wider py-1.5"]}>
      {@label}
    </span>
    """
  end

  attr :history, :list, required: true
  attr :id, :string, required: true

  defp sparkline(assigns) do
    history = Enum.take(assigns.history, -@sparkline_count)
    offset = @sparkline_count - length(history)

    bars =
      for {job, index} <- Enum.with_index(history) do
        x = (offset + index) * (@sparkline_bar_width + @sparkline_gap)
        %{x: x, color: state_color(job.state)}
      end

    tooltip_data =
      for job <- history do
        unix =
          (job.finished_at || job.attempted_at || job.scheduled_at)
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix(:millisecond)

        %{timestamp: unix, state: job.state}
      end

    placeholders =
      for slot <- 0..(@sparkline_count - 1) do
        %{x: slot * (@sparkline_bar_width + @sparkline_gap)}
      end

    width = @sparkline_count * (@sparkline_bar_width + @sparkline_gap)

    assigns =
      assigns
      |> assign(bars: bars, placeholders: placeholders, width: width, offset: offset)
      |> assign(height: @sparkline_height, bar_width: @sparkline_bar_width)
      |> assign(tooltip_data: tooltip_data)

    ~H"""
    <svg
      id={@id}
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      class="flex-shrink-0 cursor-pointer"
      phx-hook="CronSparkline"
      data-tooltip={Oban.JSON.encode!(@tooltip_data)}
      data-bar-width={@bar_width}
      data-offset={@offset}
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
        y="0"
        width={@bar_width}
        height={@height}
        fill={bar.color}
        rx="1"
      />
    </svg>
    """
  end

  defp state_color("available"), do: "#2dd4bf"
  defp state_color("cancelled"), do: "#a78bfa"
  defp state_color("completed"), do: "#22d3ee"
  defp state_color("discarded"), do: "#fb7185"
  defp state_color("executing"), do: "#fb923c"
  defp state_color("retryable"), do: "#facc15"
  defp state_color("scheduled"), do: "#34d399"
  defp state_color(_), do: "#9ca3af"

  attr :cron, Cron
  attr :id, :string

  defp cron_row(assigns) do
    ~H"""
    <li id={"cron-#{@id}"} class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30">
      <.link
        patch={oban_path([:crons, @cron.name])}
        class="pl-3 py-3.5 flex flex-grow items-center cursor-pointer"
      >
        <div class="w-1/3">
          <span class="font-semibold text-sm text-gray-700 dark:text-gray-300">
            {@cron.worker}
            <span :if={show_name?(@cron)} class="font-normal text-gray-500 dark:text-gray-400">
              ({@cron.name})
            </span>
          </span>

          <div
            :if={@cron.dynamic? or has_tags?(@cron.opts) or format_opts(@cron.opts)}
            class="flex flex-wrap items-center gap-1.5 mt-1"
          >
            <span
              :if={@cron.dynamic?}
              class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-violet-100 text-violet-700 dark:bg-violet-900/50 dark:text-violet-300"
            >
              dynamic
            </span>

            <span
              :for={tag <- get_tags(@cron.opts)}
              class="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400"
            >
              {tag}
            </span>

            <samp
              :if={format_opts(@cron.opts)}
              class="font-mono text-xs text-gray-500 dark:text-gray-400"
            >
              {format_opts(@cron.opts)}
            </samp>
          </div>
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <div class="w-80 flex justify-center">
            <.sparkline id={"sparkline-#{@cron.name}"} history={@cron.history} />
          </div>

          <span class="w-32 text-right font-mono text-sm">
            {@cron.expression}
          </span>

          <span
            class="w-32 text-right text-sm"
            id={"cron-lts-#{@cron.name}"}
            data-timestamp={maybe_to_unix(@cron.last_at)}
            phx-hook="Relativize"
            phx-update="ignore"
          >
            -
          </span>

          <span
            class="w-32 text-right text-sm"
            id={"cron-nts-#{@cron.name}"}
            data-timestamp={maybe_to_unix(@cron.next_at)}
            phx-hook="Relativize"
            phx-update="ignore"
          >
            -
          </span>

          <div class="w-20 pr-4 flex justify-end">
            <span
              id={"cron-state-icon-#{@cron.name}"}
              phx-hook="Tippy"
              data-title={state_title(@cron)}
            >
              <.state_icon state={@cron.last_state} paused={@cron.paused?} />
            </span>
          </div>
        </div>
      </.link>
    </li>
    """
  end

  defp state_title(%{paused?: true}), do: "Paused"

  defp state_title(cron) do
    case cron.last_state do
      nil -> "Unknown, no previous runs"
      state -> "#{String.capitalize(state)} as of #{NaiveDateTime.truncate(cron.last_at, :second)}"
    end
  end

  defp format_opts(opts) when map_size(opts) == 0, do: nil

  defp format_opts(opts) do
    opts
    |> Map.drop(["tags"])
    |> case do
      filtered when map_size(filtered) == 0 ->
        nil

      filtered ->
        filtered
        |> Enum.map_join(", ", fn {key, val} -> "#{key}: #{inspect(val)}" end)
        |> truncate(0..98)
    end
  end

  defp has_tags?(opts), do: Map.has_key?(opts, "tags") and opts["tags"] != []

  defp get_tags(opts), do: Map.get(opts, "tags", [])
end
