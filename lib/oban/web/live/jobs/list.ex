defmodule Oban.Web.Jobs.Table do
  use Oban.Web, :live_component

  alias Oban.Web.Resolver

  # TODO: Handle hidden
  # TODO: Handle select

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
        />
      </ul>
    </div>
    """
  end

  defp job_row(assigns) do
    ~H"""
    <li id={@id} class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950">
      <button
        class="p-3"
        rel="toggle-select"
        phx-click="toggle-select"
        phx-value-id={@job.id}
        phx-target={@myself}
      >
        <Icons.check_empty class="w-5 h-5 text-gray-400 hover:text-blue-500" />
      </button>

      <div class="py-3 truncate">
        <.link
          class="font-semibold text-sm text-gray-800 dark:text-gray-200 group-hover:text-blue-500 group-focus:outline-none group-focus:text-blue-500"
          patch={oban_path([:jobs, @job.id])}
          rel="worker"
        >
          <%= @job.worker %>
        </.link>

        <samp
          class="mt-1 block font-mono truncate text-xs text-gray-500 dark:text-gray-400"
          rel="args"
        >
          <%= format_args(@job, @resolver) %>
        </samp>
      </div>

      <div class="ml-auto py-3 text-xs text-right text-gray-500 dark:text-gray-300">
        <p class="block tabular"><%= @job.attempt %> ⁄ <%= @job.max_attempts %></p>
        <p class="inline-block px-1 py-0.5 rounded-md bg-gray-100 dark:bg-gray-800">
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

  # Helpers

  defp format_args(job, resolver, length \\ 98) do
    resolver = if function_exported?(resolver, :format_job_args, 1), do: resolver, else: Resolver

    job
    |> resolver.format_job_args()
    |> String.slice(0..length)
  end
end
