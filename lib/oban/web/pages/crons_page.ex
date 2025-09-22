defmodule Oban.Web.CronsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Web.Page

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="crons-page" class="w-full flex flex-col my-6 md:flex-row">
      <div class="bg-white dark:bg-gray-900 flex-grow rounded-md shadow-lg overflow-hidden">
        <div
          id="crons-header"
          class="pr-3 flex items-center border-b border-gray-200 dark:border-gray-700"
        >
          <div class="flex-none flex items-center pr-12">
            <Core.all_checkbox
              click="toggle-select-all"
              checked={:none}
              myself={@myself}
            />

            <h2 class="text-lg dark:text-gray-200 leading-4 font-bold">Crons</h2>
          </div>
        </div>

        <div id="crons-table" class="min-w-full">
          <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-600">
            <.header label="name" class="ml-12 w-1/3 text-left" />
            <div class="ml-auto flex items-center space-x-6">
              <.header label="schedule" class="w-32 text-right" />
              <.header label="activity" class="w-24 text-right" />
              <.header label="status" class="w-20 pr-3 text-right" />
            </div>
          </ul>

          <div :if={Enum.empty?(@crontab)} class="text-lg text-center py-12">
            <div class="flex items-center justify-center space-x-2 text-gray-600 dark:text-gray-300">
              <Icons.no_symbol /> <span>No crons are configured.</span>
            </div>
          </div>

          <ul class="divide-y divide-gray-100 dark:divide-gray-800">
            <.cron_row
              :for={{expr, worker, opts} <- @crontab}
              expr={expr}
              worker={worker}
              opts={opts}
              myself={@myself}
            />
          </ul>
        </div>
      </div>
    </div>
    """
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

  attr :expr, :string
  attr :worker, :string
  attr :opts, :map
  attr :myself, :any

  defp cron_row(assigns) do
    ~H"""
    <li
      id={"cron-#{cron_name(@worker, @opts)}"}
      class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30"
    >
      <Core.row_checkbox
        click="toggle-select"
        value={@worker}
        checked={false}
        myself={@myself}
      />

      <div class="py-2.5 flex flex-grow items-center">
        <div class="w-1/3">
          <span class="block font-semibold text-sm text-gray-700 dark:text-gray-300">
            {@worker}
          </span>

          <samp class="font-mono truncate text-xs text-gray-500 dark:text-gray-400">
            {format_opts(@opts)}
          </samp>
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <span class="w-32 text-right font-mono text-sm">
            {@expr}
          </span>

          <span class="w-24 text-right">
            -
          </span>

          <div class="w-20 pr-3 flex justify-end items-center space-x-1">
            <span class="py-1.5 px-2 text-xs rounded-md bg-gray-100 dark:bg-gray-950">
              Active
            </span>
          </div>
        </div>
      </div>
    </li>
    """
  end

  defp cron_name(worker, opts) do
    base = String.replace(worker, ".", "-")
    hash = :erlang.phash2(opts)

    "#{base}-#{hash}"
  end

  @impl Page
  def handle_mount(socket) do

    assign_new(socket, :crontab, fn -> crontab(socket.assigns.conf) end)
  end

  @impl Page
  def handle_refresh(socket) do
    assign(socket, crontab: crontab(socket.assigns.conf))
  end

  @impl Page
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-select", %{"id" => worker}, socket) do
    send(self(), {:toggle_select, worker})

    {:noreply, socket}
  end

  @impl Page
  def handle_info({:toggle_select, _worker}, socket) do
    # TODO: Implement cron selection logic
    {:noreply, socket}
  end

  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  defp crontab(conf), do: Oban.Met.crontab(conf.name)

  defp format_opts(opts) when map_size(opts) == 0, do: "%{}"

  defp format_opts(opts) do
    opts
    |> inspect(charlists: :as_lists, limit: :infinity)
    |> truncate(0..98)
  end
end
