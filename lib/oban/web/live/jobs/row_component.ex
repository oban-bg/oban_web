defmodule Oban.Web.Jobs.RowComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Resolver

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(job: assigns.job, resolver: assigns.resolver)
      |> assign(:selected?, MapSet.member?(assigns.selected, assigns.job.id))
      |> assign(:hidden?, Map.get(assigns.job, :hidden?, false))

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    hidden_class = if assigns.hidden?, do: "opacity-25 pointer-events-none"

    select_class =
      if assigns.selected?,
        do: "bg-blue-100 dark:bg-blue-400 dark:bg-opacity-25",
        else: "hover:bg-blue-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-25"

    assigns = assign(assigns, hidden_class: hidden_class, select_class: select_class)

    ~H"""
    <tr id={"job-#{@job.id}"} class={"#{@hidden_class} #{@select_class}"}>
      <td class="pl-3 py-3">
        <button rel="toggle-select" class="block" phx-click="toggle-select" phx-target={@myself}>
          <%= if @selected? do %>
            <Icons.check_selected class="w-5 h-5 text-blue-500" />
          <% else %>
            <Icons.check_empty class="w-5 h-5 text-gray-400 hover:text-blue-500" />
          <% end %>
        </button>
      </td>

      <td class="py-3 truncate max-w-0">
        <%= live_patch to: oban_path([:jobs, @job.id]), class: "flex-auto max-w-xl overflow-hidden group", "aria-label": "View job #{@job.id} details" do %>
          <span
            rel="jid"
            class="text-sm text-gray-600 dark:text-gray-300 group-hover:text-blue-500 group-focus:outline-none group-focus:text-blue-500"
          >
            <%= @job.id %>
          </span>
          <span
            rel="worker"
            class="font-semibold text-sm text-gray-800 dark:text-gray-200 group-hover:text-blue-500 group-focus:outline-none group-focus:text-blue-500 ml-1"
          >
            <%= @job.worker %>
          </span>
          <span
            rel="args"
            class="block font-mono truncate text-xs text-gray-600 dark:text-gray-300 dark:group-hover:text-gray-300 mt-2"
          >
            <%= format_args(@job, @resolver) %>
          </span>
        <% end %>
      </td>

      <td class="tabular text-sm truncate text-gray-500 dark:text-gray-300 dark:group-hover:text-gray-100 text-right py-3">
        <%= @job.queue %>
      </td>

      <td class="tabular text-sm text-gray-500 dark:text-gray-300 dark:group-hover:text-gray-100 text-right w-20 py-3">
        <%= @job.attempt %> ⁄ <%= @job.max_attempts %>
      </td>

      <td class="tabular text-sm text-gray-500 dark:text-gray-300 dark:group-hover:text-gray-100 text-right w-20 px-3">
        <%= relative_time(@job.state, @job) %>
      </td>
    </tr>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("toggle-select", _params, socket) do
    if socket.assigns.selected? do
      send(self(), {:deselect_job, socket.assigns.job})
    else
      send(self(), {:select_job, socket.assigns.job})
    end

    {:noreply, assign(socket, :selected?, not socket.assigns.selected?)}
  end

  # Helpers

  defp format_args(job, resolver, length \\ 128) do
    resolver = if function_exported?(resolver, :format_job_args, 1), do: resolver, else: Resolver

    job
    |> resolver.format_job_args()
    |> String.slice(0..length)
  end
end
