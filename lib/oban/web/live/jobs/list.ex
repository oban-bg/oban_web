defmodule Oban.Web.Jobs.Table do
  use Oban.Web, :live_component

  @inc_limit 20
  @max_limit 200
  @min_limit 20

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    resolver =
      if function_exported?(assigns.resolver, :format_job_args, 1) do
        assigns.resolver
      else
        Oban.Web.Resolver
      end

    socket =
      socket
      |> assign(jobs: assigns.jobs, params: assigns.params)
      |> assign(resolver: resolver, selected: assigns.selected)
      |> assign(show_less?: assigns.params.limit > @min_limit)
      |> assign(show_more?: assigns.params.limit < @max_limit)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="jobs-list" class="min-w-full">
      <div :if={Enum.empty?(@jobs)} class="text-lg text-center text-gray-500 dark:text-gray-400 py-12">
        <div class="flex items-center justify-center space-x-2">
          <Icons.no_symbol /> <span>No jobs match the current set of filters.</span>
        </div>
      </div>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.job_row
          :for={job <- @jobs}
          id={"job-#{job.id}"}
          job={job}
          myself={@myself}
          resolver={@resolver}
          selected={@selected}
        />
      </ul>

      <div class="py-6 flex items-center justify-center space-x-2">
        <button
          type="button"
          class={"font-semibold text-sm mr-6 focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 #{loader_class(@show_less?)}"}
          phx-target={@myself}
          phx-click="load-less"
        >
          Show Less
        </button>

        <button
          type="button"
          class={"font-semibold text-sm focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 #{loader_class(@show_more?)}"}
          phx-target={@myself}
          phx-click="load-more"
        >
          Show More
        </button>
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
          <%= @job.worker %>
        </.link>

        <span class="tabular text-xs text-gray-600" rel="attempts"><%= @job.attempt %> ⁄ <%= @job.max_attempts %></span>
        <samp
          class="ml-2 font-mono truncate text-xs text-gray-500 dark:text-gray-400"
          rel="args"
        >
          <%= format_args(@job, @resolver) %>
        </samp>
      </div>

      <div class="ml-auto py-3 text-xs text-right text-gray-500 dark:text-gray-300">
        <p class="inline-block p-1 rounded-md bg-gray-100 dark:bg-gray-950">
          <%= @job.queue %>
        </p>
      </div>

      <div
        class="py-3 pl-6 pr-3 tabular text-sm text-right text-gray-500 dark:text-gray-300 dark:group-hover:text-gray-100"
        data-timestamp={DateTime.to_unix(@job.attempted_at, :millisecond)}
        id={"job-ts-#{@job.id}"}
        phx-hook="Relativize"
        phx-update="ignore"
      >
        00:00
      </div>
    </li>
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

  # Helpers

  defp format_args(job, resolver, length \\ 98) do
    job
    |> resolver.format_job_args()
    |> truncate(0..length)
  end

  defp select_class(selected, job) do
    if MapSet.member?(selected, job.id) do
      "bg-blue-50 dark:bg-blue-950"
    else
      "hover:bg-gray-50 dark:hover:bg-gray-950"
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
