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

        <div
          id="crons-table"
          class="p-3 min-w-full grid grid-cols-[minmax(0,2.5fr)_minmax(0,0.75fr)_minmax(0,1.5fr)_minmax(0,0.2fr)] gap-y-6"
        >
          <ul class="contents text-xs py-1.5 font-medium uppercase tracking-wider text-gray-400 dark:text-gray-600 border-b border-gray-200 dark:border-gray-700">
            <li>Name</li>
            <li>Schedule</li>
            <li>Activity</li>
            <li>Status</li>
          </ul>

          <ul class="contents pt-6">
            <.cron_row
              :for={{expr, worker, opts} <- @crontab}
              expr={expr}
              worker={worker}
              opts={opts}
            />
          </ul>
        </div>
      </div>
    </div>
    """
  end

  attr :expr, :string
  attr :worker, :string
  attr :opts, :map

  defp cron_row(assigns) do
    ~H"""
    <li class="contents border-y-1 border-gray-100 dark:border-gray-800 hover:text-red-200">
      <div class="font-semibold text-gray-700 dark:text-gray-300">{@worker}</div>
      <div class="font-mono text-sm">{@expr}</div>
      <div class=""></div>
      <div class=""></div>
    </li>
    """
  end

  @impl Page
  def handle_mount(socket) do
    crontab = Oban.Met.crontab()

    assign(socket, crontab: crontab)
  end

  @impl Page
  def handle_refresh(socket) do
    socket
  end

  @impl Page
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl Page
  def handle_info(_event, socket) do
    {:noreply, socket}
  end
end
