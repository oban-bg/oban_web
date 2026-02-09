defmodule Oban.Web.Crons.DetailComponent do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="cron-details">
      <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
        <.link
          patch={oban_path(:crons, @params)}
          id="back-link"
          class="flex items-center hover:text-blue-500"
          data-title="Back to crons"
          phx-hook="Tippy"
        >
          <Icons.arrow_left class="w-5 h-5" />
          <span class="text-lg font-bold ml-2">{@cron.worker}</span>
        </.link>

        <div class="flex space-x-3">
          <div class="flex">
            <span class="flex items-center text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-blue-500 hover:border-blue-600">
              <Icons.pause_circle class="mr-2 h-5 w-5" /> Pause
            </span>
          </div>

          <div class="flex">
            <span class="inline-flex items-center px-2.5 py-0.5 rounded-md text-sm font-medium bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-300">
              <Icons.sparkles class="mr-1 h-4 w-4" /> Dynamic
            </span>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-4 gap-6 px-3 py-6">
        <div class="col-span-3">
          <div class="h-48 bg-gray-50 dark:bg-gray-800 rounded-md flex items-center justify-center">
            <span class="text-gray-400 text-sm">
              Spark chart placeholder - execution history will be displayed here
            </span>
          </div>
        </div>

        <div class="col-span-1">
          <div class="flex space-x-12 mb-6">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Last Run
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                <span
                  id="cron-last-time"
                  data-timestamp={maybe_to_unix(@cron.last_at)}
                  phx-hook="Relativize"
                  phx-update="ignore"
                >
                  -
                </span>
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Next Run
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                <span
                  id="cron-next-time"
                  data-timestamp={maybe_to_unix(@cron.next_at)}
                  phx-hook="Relativize"
                  phx-update="ignore"
                >
                  -
                </span>
              </span>
            </div>
          </div>

          <div class="flex flex-col mb-6">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
              Schedule
            </span>
            <span class="text-base text-gray-800 dark:text-gray-200">
              <code class="font-mono">{@cron.expression}</code>
            </span>
          </div>

          <div class="flex flex-col mb-6">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
              Timezone
            </span>
            <span class="text-base text-gray-800 dark:text-gray-200">
              {timezone(@cron)}
            </span>
          </div>

          <div class="flex flex-col">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
              Last Status
            </span>

            <div class="flex items-center space-x-1">
              <.state_icon state={@cron.last_state} />
              <span class="text-base text-gray-800 dark:text-gray-200">
                {state_label(@cron.last_state)}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
          <Icons.pencil_square />
          <span>Edit Configuration</span>
        </h3>
        <form
          id="cron-form"
          class="grid grid-cols-3 gap-6 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
          phx-change="form-change"
          phx-submit="local-submit"
        >
          <.field label="Schedule" />

          <.field label="Tags" />

          <.field label="Queue" />

          <.field label="Priority" />

          <.field label="Max Attempts" />

          <.field label="Guaranteed" />

          <.field label="Name" />

          <.field label="Args" colspan="col-span-2" />
        </form>
      </div>
    </div>
    """
  end

  attr :colspan, :string, default: "col-span-1"
  attr :label, :string

  def field(assigns) do
    ~H"""
    <div class={[@colspan, "bg-green-100"]}>
      <label>{@label}</label>
    </div>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("edit", _params, socket) do
    # TODO: Implement dynamic cron editing
    {:noreply, socket}
  end

  # Helpers

  defp maybe_to_unix(nil), do: ""

  defp maybe_to_unix(timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  defp timezone(%{opts: opts}) do
    Map.get(opts, "timezone") || "Etc/UTC"
  end

  defp state_label(nil), do: "Unknown"
  defp state_label(state), do: String.capitalize(state)

  attr :state, :string, required: true

  defp state_icon(%{state: nil} = assigns) do
    ~H"""
    <Icons.minus_circle class="w-5 h-5 text-gray-400" />
    """
  end

  defp state_icon(%{state: "available"} = assigns) do
    ~H"""
    <Icons.pause_circle class="w-5 h-5 text-teal-400" />
    """
  end

  defp state_icon(%{state: "cancelled"} = assigns) do
    ~H"""
    <Icons.x_circle class="w-5 h-5 text-violet-400" />
    """
  end

  defp state_icon(%{state: "completed"} = assigns) do
    ~H"""
    <Icons.check_circle class="w-5 h-5 text-cyan-400" />
    """
  end

  defp state_icon(%{state: "discarded"} = assigns) do
    ~H"""
    <Icons.exclamation_circle class="w-5 h-5 text-rose-400" />
    """
  end

  defp state_icon(%{state: "executing"} = assigns) do
    ~H"""
    <Icons.play_circle class="w-5 h-5 text-orange-400" />
    """
  end

  defp state_icon(%{state: "retryable"} = assigns) do
    ~H"""
    <Icons.arrow_path class="w-5 h-5 text-yellow-400" />
    """
  end

  defp state_icon(%{state: "scheduled"} = assigns) do
    ~H"""
    <Icons.play_circle class="w-5 h-5 text-emerald-400" />
    """
  end

  defp state_icon(assigns) do
    ~H"""
    <Icons.minus_circle class="w-5 h-5 text-gray-400" />
    """
  end
end
