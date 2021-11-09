defmodule Oban.Web.QueuesPage do
  use Oban.Web, :live_component

  alias Oban.Notifier
  alias Oban.Web.Plugins.Stats
  alias Oban.Web.Queues.{DetailComponent, TableComponent}
  alias Oban.Web.{Page, SidebarComponent, Telemetry}

  @behaviour Page

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queues-page" class="flex-1 w-full flex flex-col my-6 md:flex-row">
      <.live_component
        id="sidebar"
        module={SidebarComponent}
        sections={[:nodes]}
        counts={@counts}
        gossip={@gossip}
        page={:queues}
        params={without_defaults(@params, @default_params)}
        socket={@socket} />

      <div class="flex-grow">
        <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
          <%= if @detail do %>
            <.live_component id="detail"
              access={@access}
              conf={@conf}
              counts={@counts}
              gossip={@gossip}
              module={DetailComponent}
              queue={@detail} />
          <% else %>
            <div id="queues-header" class="flex items-center border-b border-gray-200 dark:border-gray-700 px-3 py-3">
              <h2 class="text-lg dark:text-gray-200 font-bold ml-2">Queues</h2>
              <h3 class="text-lg ml-1 text-gray-500 font-normal tabular">(<%= queues_count(@gossip) %>)</h3>
            </div>

            <.live_component
              id="queues-table"
              module={TableComponent}
              access={@access}
              counts={@counts}
              gossip={@gossip}
              expanded={@expanded}
              params={@params} />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) do
    default = fn -> %{nodes: nil, sort_by: "name", sort_dir: "asc"} end

    socket
    |> assign_new(:detail, fn -> nil end)
    |> assign_new(:params, default)
    |> assign_new(:default_params, default)
    |> assign_new(:expanded, &MapSet.new/0)
    |> assign_new(:gossip, fn -> Stats.all_gossip(socket.assigns.conf.name) end)
    |> assign_new(:counts, fn -> Stats.all_counts(socket.assigns.conf.name) end)
  end

  @impl Page
  def handle_refresh(socket) do
    counts = Stats.all_counts(socket.assigns.conf.name)
    gossip = Stats.all_gossip(socket.assigns.conf.name)

    assign(socket, counts: counts, gossip: gossip)
  end

  # Handlers

  @impl Page
  def handle_params(%{"detail" => queue}, _uri, socket) do
    title = "#{String.capitalize(queue)} Queue"

    {:noreply, assign(socket, detail: queue, page_title: page_title(title))}
  end

  def handle_params(params, _uri, socket) do
    params =
      params
      |> Map.take(["nodes", "sort_by", "sort_dir"])
      |> Map.new(fn
        {"nodes", nodes} -> {:nodes, String.split(nodes, ",")}
        {key, val} -> {String.to_existing_atom(key), val}
      end)

    socket =
      socket
      |> assign(page_title: page_title("Queues"))
      |> assign(detail: nil, params: Map.merge(socket.assigns.default_params, params))
      |> handle_refresh()

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
      # Send the notification ourselves because Oban doesn't currently support custom ident
      # pausing. At this point the name and node are already strings and we can combine the names
      # rather than using Config.to_ident.
      data = %{action: :pause, queue: queue, ident: name <> "." <> node}

      Notifier.notify(socket.assigns.conf, :signal, data)
    end)

    {:noreply, socket}
  end

  def handle_info({:toggle_queue, queue}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded, queue) do
        MapSet.delete(socket.assigns.expanded, queue)
      else
        MapSet.put(socket.assigns.expanded, queue)
      end

    {:noreply, assign(socket, expanded: expanded)}
  end

  def handle_info({:resume_queue, queue}, socket) do
    Telemetry.action(:resume_queue, socket, [queue: queue], fn ->
      Oban.resume_queue(socket.assigns.conf.name, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # Helpers

  defp queues_count(gossip) do
    gossip
    |> Enum.uniq_by(& &1["queue"])
    |> length()
  end
end
