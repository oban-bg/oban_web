defmodule Oban.Web.Crons.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Crons.Helpers, only: [maybe_to_unix: 1, show_name?: 1, state_icon: 1]

  alias Oban.Web.{Colors, Cron}

  @sparkline_count 60
  @sparkline_height 16
  @sparkline_bar_width 4
  @sparkline_gap 1

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="crons-table" class="min-w-full">
      <Core.table_header>
        <Core.column_header label="name" class="pl-3 w-1/3 text-left" />
        <div class="ml-auto flex items-center space-x-6">
          <Core.column_header label="history" class="hidden xl:block w-80 text-center" />
          <Core.column_header label="schedule" class="w-32 text-right" />
          <Core.column_header label="last run" class="w-32 text-right" />
          <Core.column_header label="next run" class="w-32 text-right" />
          <Core.column_header label="status" class="w-28 pr-4 text-right" />
        </div>
      </Core.table_header>

      <Core.no_matches
        :if={Enum.empty?(@crontab) and @filtered?}
        id="crons-no-matches"
        label="No crons match the current filters."
        clear={oban_path(:crons)}
      />

      <Core.empty_state
        :if={Enum.empty?(@crontab) and not @filtered?}
        icon="icon-clock"
        title="No crons"
      >
        Crons run jobs on a schedule. Configure them in your Oban supervisor or create them
        dynamically.
        <:actions>
          <Core.learn_link href="https://hexdocs.pm/oban/periodic_jobs.html">
            Learn about crons
          </Core.learn_link>
        </:actions>
      </Core.empty_state>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.cron_row :for={cron <- @crontab} id={cron.name} cron={cron} />
      </ul>
    </div>
    """
  end

  attr :history, :list, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true

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
      role="img"
      aria-label={@label}
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

  defp state_color(state), do: Colors.state_hex(state)

  attr :cron, Cron
  attr :id, :string

  defp cron_row(assigns) do
    ~H"""
    <li id={"cron-#{@id}"} class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30">
      <.link
        patch={oban_path([:crons, @cron.name])}
        class="pl-3 py-3.5 flex flex-grow items-center min-w-0 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-blue-500"
      >
        <div class="w-1/3 min-w-0 pr-4">
          <span class="block truncate font-semibold text-sm text-gray-700 dark:text-gray-300">
            {@cron.handler}
            <span :if={show_name?(@cron)} class="font-normal text-gray-500 dark:text-gray-400">
              ({@cron.name})
            </span>
          </span>

          <div :if={has_tags?(@cron.opts)} class="flex flex-wrap items-center gap-1.5 mt-1">
            <span
              :for={tag <- get_tags(@cron.opts)}
              class="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400"
            >
              {tag}
            </span>
          </div>
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <div class="hidden xl:flex w-80 justify-center">
            <.sparkline
              id={"sparkline-#{@cron.name}"}
              history={@cron.history}
              label={history_label(@cron.history)}
            />
          </div>

          <span class="w-32 text-right font-mono text-xs">
            <span class="sr-only">schedule</span>
            {@cron.expression}
          </span>

          <.relative_time
            id={"cron-lts-#{@cron.name}"}
            label="last run"
            timestamp={@cron.last_at}
            timezone={@cron.opts["timezone"]}
          />

          <.next_run cron={@cron} />

          <div class="w-28 pr-4 flex justify-end items-center space-x-1">
            <.mode_icon cron={@cron} />

            <span
              :if={@cron.paused?}
              id={"cron-paused-icon-#{@cron.name}"}
              class="flex items-center text-amber-500 dark:text-amber-400"
              phx-hook="Tippy"
              data-title="Paused"
            >
              <Icons.icon name="icon-pause-circle" class="w-5 h-5" />
              <span class="sr-only">Paused</span>
            </span>

            <span
              id={"cron-state-icon-#{@cron.name}"}
              class="flex items-center"
              phx-hook="Tippy"
              data-title={state_title(@cron)}
            >
              <.state_icon state={@cron.last_state} />
              <span class="sr-only">{state_title(@cron)}</span>
            </span>
          </div>
        </div>
      </.link>
    </li>
    """
  end

  attr :cron, Cron, required: true

  # A paused entry won't fire until it's resumed and a reboot entry fires whenever a node starts,
  # so neither has a countdown. Saying so beats a dash that could also mean "unknown".
  defp next_run(%{cron: %{paused?: true}} = assigns) do
    ~H"""
    <span
      id={"cron-nts-#{@cron.name}"}
      class="w-32 text-right text-sm text-gray-400 dark:text-gray-500"
    >
      <span class="sr-only">next run</span> paused
    </span>
    """
  end

  defp next_run(%{cron: %{expression: "@reboot"}} = assigns) do
    ~H"""
    <span
      id={"cron-nts-#{@cron.name}"}
      class="w-32 text-right text-sm text-gray-400 dark:text-gray-500"
    >
      <span class="sr-only">next run</span> at reboot
    </span>
    """
  end

  defp next_run(assigns) do
    ~H"""
    <.relative_time
      id={"cron-nts-#{@cron.name}"}
      label="next run"
      timestamp={@cron.next_at}
      timezone={@cron.opts["timezone"]}
    />
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :timestamp, :any, required: true
  attr :timezone, :string, default: nil

  # Relative words scan quickly but can't be checked against a log line, so the exact clock rides
  # in a tooltip. A zoned entry adds its local time so the schedule and the clock agree. The row is
  # one link, so each cell names its column for readers that can't see the header above it.
  defp relative_time(%{timestamp: nil} = assigns) do
    ~H"""
    <span id={@id} class="w-32 text-right text-sm">
      <span class="sr-only">no {@label}</span>
      <span aria-hidden="true">-</span>
    </span>
    """
  end

  defp relative_time(assigns) do
    ~H"""
    <span
      id={@id}
      class="w-32 text-right text-sm"
      data-title={absolute_time(@timestamp, @timezone)}
      phx-hook="Tippy"
    >
      <span class="sr-only">{@label}</span>
      <span
        id={"#{@id}-words"}
        data-timestamp={maybe_to_unix(@timestamp)}
        phx-hook="Relativize"
        phx-update="ignore"
      >
        -
      </span>
    </span>
    """
  end

  defp absolute_time(timestamp, nil), do: Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S UTC")

  defp absolute_time(timestamp, timezone) do
    utc = absolute_time(timestamp, nil)

    case DateTime.shift_zone(DateTime.from_naive!(timestamp, "Etc/UTC"), timezone) do
      {:ok, local} -> utc <> Calendar.strftime(local, " (%H:%M:%S %Z)")
      {:error, _reason} -> utc
    end
  end

  # The bars only carry color, so the label spells out what they show: how many runs, and how
  # they ended, in the same alphabetical order the states: filter suggests.
  defp history_label([]), do: "No runs yet"

  defp history_label(history) do
    runs = Enum.take(history, -@sparkline_count)

    counts =
      runs
      |> Enum.frequencies_by(& &1.state)
      |> Enum.sort()
      |> Enum.map_join(", ", fn {state, count} -> "#{count} #{state}" end)

    case runs do
      [_run] -> "Last run: #{counts}"
      _runs -> "Last #{length(runs)} runs: #{counts}"
    end
  end

  # The last run column already dates the job, so the state tooltip only names the outcome, in
  # the same words the states: filter suggests.
  defp state_title(%{last_state: nil}), do: "No previous jobs"

  defp state_title(%{last_state: state})
       when state in ~w(available executing retryable scheduled) do
    "Last job is #{state}"
  end

  defp state_title(%{last_state: state}), do: "Last job was #{state}"

  attr :cron, Cron, required: true

  # Dynamic and decorated are separate facts about an entry, so each gets its own glyph. They
  # lead the status cluster, ordered by permanence: how the entry is defined, whether it's paused,
  # then how its last job ended, so the fact that changes most sits at the anchored right edge.
  # Static entries are the norm and show nothing.
  defp mode_icon(%{cron: %{decorated?: true}} = assigns) do
    ~H"""
    <.slot_icon id={"cron-mode-icon-#{@cron.name}"} icon="icon-at-symbol" label="Decorated" />
    """
  end

  defp mode_icon(%{cron: %{dynamic?: true}} = assigns) do
    ~H"""
    <.slot_icon id={"cron-mode-icon-#{@cron.name}"} icon="icon-sparkles" label="Dynamic" />
    """
  end

  defp mode_icon(assigns), do: ~H""

  attr :icon, :string, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true

  defp slot_icon(assigns) do
    ~H"""
    <span
      id={@id}
      class="flex items-center text-gray-500 dark:text-gray-400"
      data-title={@label}
      phx-hook="Tippy"
    >
      <Icons.icon name={@icon} class="w-5 h-5" />
      <span class="sr-only">{@label}</span>
    </span>
    """
  end

  defp has_tags?(opts), do: Map.has_key?(opts, "tags") and opts["tags"] != []

  defp get_tags(opts), do: Map.get(opts, "tags", [])
end
