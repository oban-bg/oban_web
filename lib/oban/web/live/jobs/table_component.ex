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
      |> assign(show_more?: assigns.params.limit < @max_limit)

    {:ok, socket}
  end

  attr :label, :string, required: true
  attr :class, :string, default: ""

  defp header(assigns) do
    ~H"""
    <span class={[@class, "text-xs font-medium uppercase tracking-wider py-1.5 pl-4"]}>
      {@label}
    </span>
    """
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="jobs-table" class="min-w-full">
      <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-600">
        <.header label="details" class="ml-12" />
        <.header label="queue" class="ml-auto text-right" />
        <.header label="time" class="w-20 pr-3 text-right" />
      </ul>

      <div :if={Enum.empty?(@jobs)} class="text-lg text-center py-12">
        <div class="flex items-center justify-center space-x-2 text-gray-600 dark:text-gray-300">
          <Icons.no_symbol /> <span>No jobs match the current set of filters.</span>
        </div>
        <p :if={is_integer(@query_limit)} class="mt-2 text-xs text-gray-500 dark:text-gray-400">
          Filtering limited to latest {integer_to_delimited(@query_limit)} jobs. See <a
            class="underline"
            href="https://oban.pro/docs/web/filtering.html"
          >filtering docs</a>.
        </p>
      </div>

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

      <div class="py-6 flex items-center justify-center space-x-6">
        <.load_button label="Show Less" click="load-less" active={@show_less?} myself={@myself} />
        <.load_button label="Show More" click="load-more" active={@show_more?} myself={@myself} />
      </div>
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
        myself={@myself}
      />

      <.link patch={oban_path([:jobs, @job.id])} class="flex flex-grow items-center">
        <div class="py-2.5">
          <span class="block font-semibold text-sm text-gray-700 dark:text-gray-300" rel="worker">
            {@job.worker}
          </span>

          <span class="tabular text-xs text-gray-600 dark:text-gray-300" rel="attempts">
            {@job.attempt} ⁄ {@job.max_attempts}
          </span>

          <samp class="ml-2 font-mono truncate text-xs text-gray-500 dark:text-gray-400" rel="args">
            {format_args(@job, @resolver)}
          </samp>
        </div>

        <div class="ml-auto flex items-center space-x-1">
          <Icons.life_buoy
            :if={Map.has_key?(@job.meta, "rescued")}
            class="h-5 w-5 text-gray-500 dark:text-gray-300"
            id={"job-rescued-#{assigns.job.id}"}
            phx-hook="Tippy"
            data-title="Rescued by the DynamicLifeline plugin"
          />

          <Icons.crossbones_circle
            :if={orphaned?(@job, @producers)}
            class="h-5 w-5 text-gray-500 dark:text-gray-300"
            id={"job-orphaned-#{assigns.job.id}"}
            phx-hook="Tippy"
            data-title="Orphaned, host node shut down"
          />

          <span class="py-1.5 px-2 tabular truncate text-xs rounded-md bg-gray-100 dark:bg-gray-950">
            {@job.queue}
          </span>
        </div>

        <div
          class="w-20 pr-3 text-sm text-right tabular text-gray-500 dark:text-gray-300 dark:group-hover:text-gray-100"
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

  defp load_button(assigns) do
    ~H"""
    <button
      type="button"
      class={"font-semibold text-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 #{loader_class(@active)}"}
      phx-target={@myself}
      phx-click={@click}
    >
      {@label}
    </button>
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

  # Time Helpers

  defp timestamp(job) do
    datetime =
      case job.state do
        "available" -> job.scheduled_at
        "cancelled" -> job.cancelled_at
        "completed" -> job.completed_at
        "discarded" -> job.discarded_at
        "executing" -> job.attempted_at
        "retryable" -> job.scheduled_at
        "scheduled" -> job.scheduled_at
      end

    DateTime.to_unix(datetime, :millisecond)
  end

  defp relative_mode(job) do
    if job.state == "executing", do: "duration", else: "words"
  end

  # Class Helpers

  defp hidden_class(%{hidden?: true}), do: "opacity-25 pointer-events-none"
  defp hidden_class(_job), do: ""

  defp loader_class(true) do
    """
    text-gray-700 dark:text-gray-300 cursor-pointer transition ease-in-out duration-200 border-b
    border-gray-200 dark:border-gray-800 hover:border-gray-400
    """
  end

  defp loader_class(_), do: "text-gray-400 dark:text-gray-600 cursor-not-allowed"
end
