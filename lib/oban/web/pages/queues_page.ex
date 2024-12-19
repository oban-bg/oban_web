defmodule Oban.Web.QueuesPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Met

  alias Oban.Web.Queues.{DetailComponent, DetailInsanceComponent}
  alias Oban.Web.Queues.{SidebarComponent, TableComponent}
  alias Oban.Web.{Page, QueueQuery, SearchComponent, SortComponent, Telemetry}

  @known_params ~w(modes nodes sort_by sort_dir stats)

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queues-page" class="w-full flex flex-col my-6 md:flex-row">
      <SidebarComponent.sidebar queues={@queues} params={without_defaults(@params, @default_params)} />

      <div class="flex-grow">
        <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
          <%= if @detail do %>
            <.live_component
              id="detail"
              access={@access}
              conf={@conf}
              checks={@checks}
              module={DetailComponent}
              queue={@detail}
            />
          <% else %>
            <div
              id="queues-header"
              class="pr-3 flex items-center border-b border-gray-200 dark:border-gray-700"
            >
              <div class="flex-none flex items-center pr-12">
                <Core.all_checkbox
                  click="toggle-select-all"
                  checked={select_mode(@checks, @selected)}
                  myself={@myself}
                />

                <h2 class="text-lg dark:text-gray-200 leading-4 font-bold">Queues</h2>
              </div>

              <div
                :if={Enum.any?(@selected)}
                id="bulk-actions"
                class="ml-6 flex items-center space-x-3"
              >
                <Core.action_button
                  :if={can?(:pause_queues, @access)}
                  label="Pause"
                  click="pause-queues"
                  target={@myself}
                >
                  <:icon><Icons.pause_circle class="w-5 h-5" /></:icon>
                  <:title>Pause Queues</:title>
                </Core.action_button>

                <Core.action_button
                  :if={can?(:pause_queues, @access)}
                  label="Resume"
                  click="resume-queues"
                  target={@myself}
                >
                  <:icon><Icons.play_circle class="w-5 h-5" /></:icon>
                  <:title>Resume Queues</:title>
                </Core.action_button>

                <Core.action_button
                  :if={can?(:stop_queues, @access)}
                  label="Stop"
                  click="stop-queues"
                  target={@myself}
                  danger={true}
                >
                  <:icon><Icons.x_circle class="w-5 h-5" /></:icon>
                  <:title>Stop Queues</:title>
                </Core.action_button>
              </div>

              <.live_component
                :if={Enum.empty?(@selected)}
                conf={@conf}
                id="search"
                module={SearchComponent}
                page={:queues}
                params={without_defaults(@params, @default_params)}
                queryable={QueueQuery}
                resolver={@resolver}
              />

              <div class="pl-3 ml-auto">
                <span
                  :if={Enum.any?(@selected)}
                  id="selected-count"
                  class="block text-sm font-semibold mr-3"
                >
                  {MapSet.size(@selected)} Selected
                </span>

                <SortComponent.select
                  :if={Enum.empty?(@selected)}
                  id="queues-sort"
                  by={~w(name nodes avail exec local global rate_limit started)}
                  page={:queues}
                  params={@params}
                />
              </div>
            </div>

            <.live_component
              id="queues-table"
              module={TableComponent}
              access={@access}
              params={@params}
              queues={@queues}
              selected={@selected}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) do
    default = fn -> %{sort_by: "name", sort_dir: "asc"} end

    socket
    |> assign_new(:checks, fn -> checks(socket.assigns.conf) end)
    |> assign_new(:counts, fn -> counts(socket.assigns.conf) end)
    |> assign_new(:default_params, default)
    |> assign_new(:detail, fn -> nil end)
    |> assign_new(:params, default)
    |> assign_new(:queues, fn -> [] end)
    |> assign_new(:selected, &MapSet.new/0)
  end

  @impl Page
  def handle_refresh(socket) do
    conf = socket.assigns.conf
    queues = QueueQuery.all_queues(socket.assigns.params, conf)

    assign(socket, counts: counts(conf), checks: checks(conf), queues: queues)
  end

  defp checks(conf) do
    Met.checks(conf.name)
  end

  defp counts(conf) do
    Met.latest(conf.name, :full_count, group: "queue", filters: [state: "available"])
  end

  defp select_mode(checks, selected) do
    total = checks |> Enum.uniq_by(&Map.get(&1, "queue")) |> Enum.count()

    cond do
      Enum.any?(selected) and Enum.count(selected) == total -> :all
      Enum.any?(selected) -> :some
      true -> :none
    end
  end

  # Handlers

  @impl Page
  def handle_params(%{"id" => queue}, _uri, socket) do
    title = "#{String.capitalize(queue)} Queue"

    if Enum.any?(socket.assigns.checks, &(&1["queue"] == queue)) do
      {:noreply, assign(socket, detail: queue, page_title: page_title(title))}
    else
      {:noreply, push_patch(socket, to: oban_path(:queues), replace: true)}
    end
  end

  def handle_params(params, _uri, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params()

    socket =
      socket
      |> assign(page_title: page_title("Queues"))
      |> assign(detail: nil, params: Map.merge(socket.assigns.default_params, params))
      |> handle_refresh()

    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("pause-queues", _params, socket) do
    send(self(), :pause_queues)

    {:noreply, socket}
  end

  def handle_event("resume-queues", _params, socket) do
    send(self(), :resume_queues)

    {:noreply, socket}
  end

  def handle_event("stop-queues", _params, socket) do
    send(self(), :stop_queues)

    {:noreply, socket}
  end

  def handle_event("toggle-select-all", _params, socket) do
    send(self(), :toggle_select_all)

    {:noreply, socket}
  end

  @impl Page
  def handle_info({:pause_queue, queue}, socket) do
    Telemetry.action(:pause_queue, socket, [queue: queue], fn ->
      Oban.pause_queue(socket.assigns.conf.name, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info({:pause_queue, queue, name, node}, socket) do
    Telemetry.action(:pause_queue, socket, [queue: queue, name: name, node: node], fn ->
      Oban.pause_queue(socket.assigns.conf.name, node: node, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info({:resume_queue, queue}, socket) do
    Telemetry.action(:resume_queue, socket, [queue: queue], fn ->
      Oban.resume_queue(socket.assigns.conf.name, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info({:resume_queue, queue, name, node}, socket) do
    Telemetry.action(:resume_queue, socket, [queue: queue, name: name, node: node], fn ->
      Oban.resume_queue(socket.assigns.conf.name, node: node, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info(:pause_queues, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    Telemetry.action(:pause_queues, socket, [], fn ->
      Enum.each(socket.assigns.selected, &Oban.pause_queue(socket.assigns.conf.name, queue: &1))
    end)

    socket =
      socket
      |> assign(:selected, MapSet.new())
      |> put_flash_with_clear(:info, "Selected queues paused")

    {:noreply, socket}
  end

  def handle_info(:resume_queues, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    Telemetry.action(:resume_queues, socket, [], fn ->
      Enum.each(socket.assigns.selected, &Oban.resume_queue(socket.assigns.conf.name, queue: &1))
    end)

    socket =
      socket
      |> assign(:selected, MapSet.new())
      |> put_flash_with_clear(:info, "Selected queues resumed")

    {:noreply, socket}
  end

  def handle_info(:stop_queues, socket) do
    enforce_access!(:stop_queues, socket.assigns.access)

    Telemetry.action(:stop_queues, socket, [], fn ->
      Enum.each(socket.assigns.selected, &Oban.stop_queue(socket.assigns.conf.name, queue: &1))
    end)

    socket =
      socket
      |> assign(:selected, MapSet.new())
      |> put_flash_with_clear(:info, "Selected queues stopped")

    {:noreply, socket}
  end

  def handle_info({:toggle_select, queue}, socket) do
    selected = socket.assigns.selected

    selected =
      if MapSet.member?(selected, queue) do
        MapSet.delete(selected, queue)
      else
        MapSet.put(selected, queue)
      end

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_info(:toggle_select_all, socket) do
    selected =
      if Enum.any?(socket.assigns.selected) do
        MapSet.new()
      else
        socket.assigns.params
        |> QueueQuery.all_queues(socket.assigns.conf)
        |> MapSet.new(& &1.name)
      end

    {:noreply, assign(socket, selected: selected)}
  end

  def handle_info({:scale_queue, queue, name, node, limit}, socket) do
    meta = [queue: queue, name: name, node: node, limit: limit]

    Telemetry.action(:scale_queue, socket, meta, fn ->
      Oban.scale_queue(socket.assigns.conf.name, node: node, queue: queue, limit: limit)
    end)

    send_update(DetailComponent, id: "detail", local_limit: limit)

    {:noreply,
     put_flash_with_clear(socket, :info, "Local limit set for #{queue} queue on #{node}")}
  end

  def handle_info({:scale_queue, queue, opts}, socket) do
    opts = Keyword.put(opts, :queue, queue)

    Telemetry.action(:scale_queue, socket, opts, fn ->
      Oban.scale_queue(socket.assigns.conf.name, opts)
    end)

    if Keyword.has_key?(opts, :limit) do
      for checks <- socket.assigns.checks do
        send_update(DetailInsanceComponent, id: node_name(checks), local_limit: opts[:limit])
      end
    end

    {:noreply, put_flash_with_clear(socket, :info, scale_message(queue, opts))}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # Socket Helpers

  defp scale_message(queue, opts) do
    cond do
      Keyword.has_key?(opts, :global_limit) and is_nil(opts[:global_limit]) ->
        "Global limit disabled for #{queue} queue"

      Keyword.has_key?(opts, :global_limit) ->
        "Global limit set for #{queue} queue"

      Keyword.has_key?(opts, :rate_limit) and is_nil(opts[:rate_limit]) ->
        "Rate limit disabled for #{queue} queue"

      Keyword.has_key?(opts, :rate_limit) ->
        "Rate limit set for #{queue} queue"

      Keyword.has_key?(opts, :limit) ->
        "Local limit set for #{queue} queue"
    end
  end
end
