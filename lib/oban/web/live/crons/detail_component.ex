defmodule Oban.Web.Crons.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Resolver

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
          <span class="text-lg font-bold ml-2">Cron Details</span>
        </.link>

        <div class="flex">
          <%= if @cron.dynamic? do %>
            <button
              id="detail-edit"
              class="group flex items-center ml-4 text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 hover:text-blue-500 hover:border-blue-600"
              phx-target={@myself}
              phx-click="edit"
              type="button"
            >
              <Icons.pencil_square class="-ml-1 mr-1 h-5 w-5 text-gray-500 group-hover:text-blue-500" />
              Edit
            </button>
          <% end %>
        </div>
      </div>

      <div class="grid grid-cols-5 gap-6 border-b border-gray-200 dark:border-gray-700 px-3 py-6">
        <!-- Header section (2fr equivalent) -->
        <div class="col-span-2">
          <div class="flex items-start justify-between mb-4">
            <h2 class="text-xl font-bold text-gray-900 dark:text-gray-200">
              {@cron.worker}
            </h2>
            <Icons.sparkles
              :if={@cron.dynamic?}
              id="cron-dynamic-indicator"
              class="w-6 h-6 text-amber-500"
              phx-hook="Tippy"
              data-title="Dynamic cron"
            />
          </div>

          <div class="space-y-3">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
                Schedule
              </span>
              <code class="font-mono text-sm text-gray-900 dark:text-gray-200">{@cron.expression}</code>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
                Type
              </span>
              <span class="text-sm text-gray-900 dark:text-gray-200">
                {if @cron.dynamic?, do: "Dynamic", else: "Static"}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
                Last Run
              </span>
              <span class="text-sm text-gray-900 dark:text-gray-200">
                <span
                  :if={@cron.last_at}
                  id="cron-last-time"
                  data-timestamp={maybe_to_unix(@cron.last_at)}
                  phx-hook="Relativize"
                  phx-update="ignore"
                >
                  -
                </span>
                <span :if={is_nil(@cron.last_at)} class="text-gray-400">Never</span>
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
                Next Run
              </span>
              <span class="text-sm text-gray-900 dark:text-gray-200">
                <span
                  :if={@cron.next_at}
                  id="cron-next-time"
                  data-timestamp={maybe_to_unix(@cron.next_at)}
                  phx-hook="Relativize"
                  phx-update="ignore"
                >
                  -
                </span>
                <span :if={is_nil(@cron.next_at)} class="text-gray-400">Not scheduled</span>
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400">
                Status
              </span>
              <span class="flex items-center space-x-1 text-sm text-gray-900 dark:text-gray-200">
                <.state_icon state={@cron.last_state} />
                <span class="capitalize">{@cron.last_state || "unknown"}</span>
              </span>
            </div>
          </div>
        </div>

        <!-- Execution History section (3fr equivalent) -->
        <div class="col-span-3">
          <h3 class="flex font-semibold mb-3 space-x-2 text-gray-700 dark:text-gray-300">
            <Icons.chart_bar_square />
            <span>Execution History</span>
          </h3>
          <div class="h-32 bg-gray-50 dark:bg-gray-800 rounded-md flex items-center justify-center">
            <span class="text-gray-400 text-sm">Spark chart placeholder - execution history will be displayed here</span>
          </div>
        </div>
      </div>

      <!-- Placeholder for dynamic cron edit form -->
      <%= if @cron.dynamic? do %>
        <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
          <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
            <Icons.cog_8_tooth />
            <span>Configuration</span>
          </h3>
          <div class="bg-gray-50 dark:bg-gray-800 rounded-md p-4">
            <span class="text-gray-400 text-sm">Dynamic cron edit form placeholder - configuration options will be displayed here</span>
          </div>
        </div>
      <% end %>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
          <Icons.command_line />
          <span>Job Options</span>
        </h3>
        <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all">{format_opts(@cron.opts, @resolver)}</pre>
      </div>
    </div>
    """
  end

  attr :state, :string, required: true
  attr :rest, :global

  defp state_icon(assigns) do
    ~H"""
    <%= case @state do %>
      <% "available" -> %>
        <Icons.pause_circle class="w-4 h-4 text-teal-400" />
      <% "cancelled" -> %>
        <Icons.x_circle class="w-4 h-4 text-violet-400" />
      <% "completed" -> %>
        <Icons.check_circle class="w-4 h-4 text-cyan-400" />
      <% "discarded" -> %>
        <Icons.exclamation_circle class="w-4 h-4 text-rose-400" />
      <% "executing" -> %>
        <Icons.play_circle class="w-4 h-4 text-orange-400" />
      <% "retryable" -> %>
        <Icons.arrow_path class="w-4 h-4 text-yellow-400" />
      <% "scheduled" -> %>
        <Icons.play_circle class="w-4 h-4 text-emerald-400" />
      <% _ -> %>
        <Icons.minus_circle class="w-4 h-4 text-gray-400" />
    <% end %>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("edit", _params, socket) do
    # TODO: Implement dynamic cron editing
    {:noreply, socket}
  end

  # Helpers

  defp format_opts(opts, resolver) do
    case opts do
      opts when map_size(opts) == 0 -> "{}"
      opts -> Resolver.call_with_fallback(resolver, :format_cron_opts, [opts])
    end
  end

  defp maybe_to_unix(nil), do: ""

  defp maybe_to_unix(timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end
end
