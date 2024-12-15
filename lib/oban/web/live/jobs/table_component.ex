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

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="jobs-table" class="min-w-full">
      <div :if={Enum.empty?(@jobs)} class="text-lg text-center py-12">
        <div class="flex items-center justify-center space-x-2 text-gray-600 dark:text-gray-300">
          <Icons.no_symbol /> <span>No jobs match the current set of filters.</span>
        </div>
        <p :if={is_integer(@query_limit)} class="mt-2 text-xs text-gray-500 dark:text-gray-400">
          Filtering limited to latest {integer_to_delimited(@query_limit)} jobs. See <a
            class="underline"
            href="https://getoban.pro/docs/web/filtering.html"
          >filtering docs</a>.
        </p>
      </div>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.job_row
          :for={job <- @jobs}
          id={"job-#{job.id}"}
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
    <li id={@id} class={"flex items-center #{select_class(@selected, @job)} #{hidden_class(@job)}"}>
      <button
        class="p-3"
        rel="toggle-select"
        phx-click="toggle-select"
        phx-value-id={@job.id}
        phx-target={@myself}
      >
        <%= if MapSet.member?(@selected, @job.id) do %>
          <Icons.check_selected class="w-5 h-5 text-blue-500" />
        <% else %>
          <Icons.check_empty class="w-5 h-5 text-gray-400 hover:text-blue-500" />
        <% end %>
      </button>

      <div class="py-3">
        <.link
          class="block font-semibold text-sm text-gray-800 dark:text-gray-200 hover:text-blue-500 focus:outline-none focus:text-blue-500"
          patch={oban_path([:jobs, @job.id])}
          rel="worker"
        >
          {@job.worker}
        </.link>

        <span class="tabular text-xs text-gray-600 dark:text-gray-300" rel="attempts">
          {@job.attempt} ⁄ {@job.max_attempts}
        </span>
        <samp class="ml-2 font-mono truncate text-xs text-gray-500 dark:text-gray-400" rel="args">
          {format_args(@job, @resolver)}
        </samp>
      </div>

      <div class="ml-auto py-3 pr-3 flex items-center space-x-1">
        <p class="py-1.5 px-2 text-xs rounded-md bg-gray-100 dark:bg-gray-950">
          {@job.queue}
        </p>

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

        <div
          class="w-16 tabular text-sm text-right text-gray-500 dark:text-gray-300 dark:group-hover:text-gray-100"
          data-timestamp={timestamp(@job)}
          data-relative-mode={relative_mode(@job)}
          id={"job-ts-#{@job.id}"}
          phx-hook="Relativize"
          phx-update="ignore"
        >
          00:00
        </div>
      </div>
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
    resolver = if function_exported?(resolver, :jobs_query_limit, 1), do: resolver, else: Resolver

    params.state
    |> String.to_existing_atom()
    |> resolver.jobs_query_limit()
  end

  defp format_args(job, resolver) do
    resolver = if function_exported?(resolver, :format_job_args, 1), do: resolver, else: Resolver

    job
    |> resolver.format_job_args()
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

  defp select_class(selected, job) do
    if MapSet.member?(selected, job.id) do
      "bg-blue-50 dark:bg-blue-950"
    else
      "hover:bg-gray-50 dark:hover:bg-gray-950/30"
    end
  end

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
