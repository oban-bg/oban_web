defmodule Oban.Web.Jobs.TableComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Resolver

  @inc_limit 20
  @max_limit 200
  @min_limit 20

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    producers =
      assigns.conf.name
      |> Oban.Met.checks()
      |> Enum.map(& &1["uuid"])
      |> MapSet.new()

    socket =
      socket
      |> assign(jobs: assigns.jobs, params: assigns.params)
      |> assign(query_limit: query_limit(assigns.resolver, assigns.params))
      |> assign(producers: producers, resolver: assigns.resolver, selected: assigns.selected)
      |> assign(show_less?: assigns.params.limit > @min_limit)
      |> assign(show_more?: assigns.params.limit < @max_limit and full_page?(assigns))
      |> assign(capped?: assigns.params.limit >= @max_limit and full_page?(assigns))
      |> assign(max_limit: @max_limit)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="jobs-table" class="min-w-full">
      <Core.table_header>
        <Core.column_header label="details" class="ml-12 pl-4" />
        <Core.column_header label="queue" class="ml-auto pl-4 text-right" />
        <Core.column_header label={time_label(@params.state)} class="w-28 pl-4 pr-3 text-right" />
      </Core.table_header>

      <Core.no_matches
        :if={Enum.empty?(@jobs)}
        id="jobs-no-matches"
        label="No jobs match the current filters."
        clear={oban_path(:jobs)}
      >
        <p :if={is_integer(@query_limit)} class="mt-2 text-xs text-gray-500 dark:text-gray-400">
          Filtering limited to latest {integer_to_delimited(@query_limit)} jobs. See <a
            class="underline"
            href="https://oban.pro/docs/web/filtering.html"
          >filtering docs</a>.
        </p>
      </Core.no_matches>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.job_row
          :for={job <- @jobs}
          job={job}
          myself={@myself}
          producers={@producers}
          resolver={@resolver}
          selected={@selected}
        />
      </ul>

      <Core.load_footer
        capped?={@capped?}
        label="jobs"
        max_limit={@max_limit}
        myself={@myself}
        show_less?={@show_less?}
        show_more?={@show_more?}
      />
    </div>
    """
  end

  defp job_row(assigns) do
    ~H"""
    <li
      id={"job-#{@job.id}"}
      class={["flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30", hidden_class(@job)]}
    >
      <Core.row_checkbox
        click="toggle-select"
        value={@job.id}
        checked={MapSet.member?(@selected, @job.id)}
        label={"Select job #{@job.id}"}
        myself={@myself}
      />

      <.link
        patch={oban_path([:jobs, @job.id])}
        phx-click={JS.dispatch("phx:scroll-top", to: "body")}
        class="flex flex-grow items-center focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-blue-500"
      >
        <div class="py-2.5">
          <span class="block font-semibold text-sm text-gray-700 dark:text-gray-300" rel="worker">
            {Map.get(@job.meta, "decorated_name", @job.worker)}
          </span>

          <span class="mr-2 tabular text-xs text-gray-500 dark:text-gray-400" rel="id">
            {"#"}{@job.id}
          </span>

          <span class="tabular text-xs text-gray-600 dark:text-gray-300" rel="attempts">
            {@job.attempt} ⁄ {@job.max_attempts}
          </span>

          <samp class="ml-2 font-mono truncate text-xs text-gray-500 dark:text-gray-400" rel="args">
            {format_args(@job, @resolver)}
          </samp>
        </div>

        <div class="ml-auto flex items-center space-x-1">
          <.flag_icon
            :if={Map.has_key?(@job.meta, "rescued")}
            icon="icon-life-buoy"
            id={"job-rescued-#{@job.id}"}
            label="Rescued by lifeline"
          />

          <.flag_icon
            :if={orphaned?(@job, @producers)}
            icon="icon-crossbones-circle-solid"
            id={"job-orphaned-#{@job.id}"}
            label="Orphaned, host node shut down"
          />

          <.flag_icon
            :if={chunk_sibling?(@job)}
            icon="icon-user-group"
            id={"job-chunk-#{@job.id}"}
            label={"In a chunk led by job #{chunk_leader_id(@job)}"}
          />

          <span
            :if={chunk_leader?(@job)}
            id={"job-chunk-#{@job.id}"}
            class="flex items-center space-x-1 py-1.5 px-2 tabular text-xs rounded-md bg-gray-100 dark:bg-gray-950"
            phx-hook="Tippy"
            data-title={chunk_tooltip(@job)}
          >
            <Icons.icon name="icon-user-group" class="h-4 w-4 text-gray-500 dark:text-gray-300" />
            <span :if={chunk_count(@job)}>{chunk_count(@job)}</span>
            <span class="sr-only">{chunk_tooltip(@job)}</span>
          </span>

          <span class="py-1.5 px-2 tabular truncate text-xs rounded-md bg-gray-100 dark:bg-gray-950">
            {@job.queue}
          </span>
        </div>

        <div
          class="w-28 pr-3 text-sm text-right tabular text-gray-500 dark:text-gray-300"
          data-timestamp={timestamp(@job)}
          data-relative-mode={relative_mode(@job)}
          id={"job-ts-#{@job.id}"}
          phx-hook="Relativize"
          phx-update="ignore"
        >
          00:00
        </div>
      </.link>
    </li>
    """
  end

  attr :icon, :string, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true

  defp flag_icon(assigns) do
    ~H"""
    <span class="flex items-center" data-title={@label} id={@id} phx-hook="Tippy">
      <Icons.icon name={@icon} class="h-5 w-5 text-gray-500 dark:text-gray-300" />
      <span class="sr-only">{@label}</span>
    </span>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-select", %{"id" => id}, socket) do
    send(self(), {:toggle_select, String.to_integer(id)})

    {:noreply, socket}
  end

  def handle_event("load-less", _params, socket) do
    if socket.assigns.show_less? do
      send(self(), {:params, :limit, -@inc_limit})
    end

    {:noreply, socket}
  end

  def handle_event("load-more", _params, socket) do
    if socket.assigns.show_more? do
      send(self(), {:params, :limit, @inc_limit})
    end

    {:noreply, socket}
  end

  # A short page means there is nothing more to load, so the controls stay hidden until the
  # rows fill the current limit.
  defp full_page?(assigns), do: length(assigns.jobs) == assigns.params.limit

  # Resolver Helpers

  defp query_limit(resolver, params) do
    state = String.to_existing_atom(params.state)

    Resolver.call_with_fallback(resolver, :jobs_query_limit, [state])
  end

  defp format_args(job, resolver) do
    resolver
    |> Resolver.call_with_fallback(:format_job_args, [job])
    |> truncate(0..98)
  end

  # Chunk Helpers

  defp chunk_tooltip(job) do
    case {chunk_count(job), job.state} do
      {nil, "executing"} -> "Waiting for a full chunk"
      {nil, _state} -> "Led a chunk"
      {1, "executing"} -> "Leading a chunk of 1 job"
      {count, "executing"} -> "Leading a chunk of #{count} jobs"
      {1, _state} -> "Led a chunk of 1 job"
      {count, _state} -> "Led a chunk of #{count} jobs"
    end
  end

  # Time Helpers

  # The column shows a different timestamp for each state, so the header names what the value
  # means rather than a generic "time".
  defp time_label("available"), do: "available"
  defp time_label("executing"), do: "running"
  defp time_label("retryable"), do: "next retry"
  defp time_label("completed"), do: "finished"
  defp time_label("cancelled"), do: "cancelled"
  defp time_label("discarded"), do: "discarded"
  defp time_label(_state), do: "scheduled"

  defp timestamp(job) do
    datetime =
      case job do
        %{state: state, scheduled_at: at}
        when state in ~w(available scheduled suspended retryable) ->
          at

        %{state: "executing", attempted_at: at} ->
          at

        %{state: "cancelled", cancelled_at: at} ->
          at

        %{state: "completed", completed_at: at} ->
          at

        %{state: "discarded", discarded_at: at} ->
          at
      end

    if is_struct(datetime) do
      DateTime.to_unix(datetime, :millisecond)
    else
      "-"
    end
  end

  defp relative_mode(job) do
    if job.state == "executing", do: "duration", else: "words"
  end

  # Class Helpers

  defp hidden_class(%{hidden?: true}), do: "opacity-25 pointer-events-none"
  defp hidden_class(_job), do: ""
end
