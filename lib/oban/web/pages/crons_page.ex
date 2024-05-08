defmodule Oban.Web.CronsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Web.Page

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="crons-page" class="w-full flex flex-col my-6 space-x-3 md:flex-row">
      <div id="sidebar" class="w-fill md:w-84 space-y-3">
        <p>Stuff goes here</p>
        <p>More stuff here</p>
      </div>

      <div class="bg-white dark:bg-gray-900 flex-grow rounded-md shadow-lg overflow-hidden">
        <div id="crons-table" class="p-3 min-w-full grid grid-cols-[minmax(0,2fr)_minmax(0,0.75fr)_minmax(0,1.5fr)_minmax(0,1fr)] gap-y-6">
          <ul class="contents text-xs py-1 font-semibold text-gray-400 dark:text-gray-600 uppercase">
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
    <li class="contents border-y-1 border-gray-100 dark:border-gray-800">
      <div class="font-semibold text-gray-700 dark:text-gray-300"><%= @worker %></div>
      <div class="font-mono text-sm"><%= @expr %></div>
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
