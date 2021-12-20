defmodule Oban.Web.QueuesPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Notifier
  alias Oban.Web.Plugins.Stats
  alias Oban.Web.Queues.{DetailComponent, DetailInsanceComponent, TableComponent}
  alias Oban.Web.{Page, SidebarComponent, Telemetry}

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
            <.live_component
              id="detail"
              access={@access}
              conf={@conf}
              counts={@counts}
              gossip={@gossip}
              module={DetailComponent}
              queue={@detail} />
          <% else %>
            <div id="queues-header" class="flex items-center border-b border-gray-200 dark:border-gray-700 space-x-2 px-3 py-6">
              <h2 class="text-lg dark:text-gray-200 leading-4 font-bold">Queues</h2>
              <h3 class="text-lg text-gray-500 leading-4 font-normal tabular">(<%= queues_count(@gossip) %>)</h3>
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
  def handle_params(%{"id" => queue}, _uri, socket) do
    title = "#{String.capitalize(queue)} Queue"

    if Enum.any?(socket.assigns.gossip, &(&1["queue"] == queue)) do
      {:noreply, assign(socket, detail: queue, page_title: page_title(title))}
    else
      {:noreply, push_patch(socket, to: oban_path(:queues), replace: true)}
    end
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
  def handle_info({:toggle_queue, queue}, socket) do
    expanded =
      if MapSet.member?(socket.assigns.expanded, queue) do
        MapSet.delete(socket.assigns.expanded, queue)
      else
        MapSet.put(socket.assigns.expanded, queue)
      end

    {:noreply, assign(socket, expanded: expanded)}
  end

  def handle_info({:pause_queue, queue}, socket) do
    Telemetry.action(:pause_queue, socket, [queue: queue], fn ->
      Oban.pause_queue(socket.assigns.conf.name, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info({:pause_queue, queue, name, node}, socket) do
    Telemetry.action(:pause_queue, socket, [queue: queue, name: name, node: node], fn ->
      notify_scoped(socket.assigns.conf, name, node, action: :pause, queue: queue)
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
      notify_scoped(socket.assigns.conf, name, node, action: :resume, queue: queue)
    end)

    {:noreply, socket}
  end

  def handle_info({:scale_queue, queue, name, node, limit}, socket) do
    meta = [queue: queue, name: name, node: node, limit: limit]

    Telemetry.action(:scale_queue, socket, meta, fn ->
      notify_scoped(socket.assigns.conf, name, node, action: :scale, queue: queue, limit: limit)
    end)

    send_update(DetailComponent, id: "detail", local_limit: limit)

    {:noreply, flash(socket, :info, "Local limit set for #{queue} queue on #{node}")}
  end

  def handle_info({:scale_queue, queue, opts}, socket) do
    opts = Keyword.put(opts, :queue, queue)

    Telemetry.action(:scale_queue, socket, opts, fn ->
      Oban.scale_queue(socket.assigns.conf.name, opts)
    end)

    if Keyword.has_key?(opts, :limit) do
      for gossip <- socket.assigns.gossip do
        send_update(DetailInsanceComponent, id: node_name(gossip), local_limit: opts[:limit])
      end
    end

    {:noreply, flash(socket, :info, scale_message(queue, opts))}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # Helpers

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

  # Send the notification ourselves because Oban doesn't currently support custom ident pausing.
  # At this point the name and node are already strings and we can combine the names rather than
  # using Config.to_ident.
  defp notify_scoped(conf, name, node, data) do
    message =
      data
      |> Map.new()
      |> Map.put(:ident, name <> "." <> node)

    Notifier.notify(conf, :signal, message)
  end

  defp flash(socket, mode, message, timing \\ 5_000) do
    Process.send_after(self(), :clear_flash, timing)

    put_flash(socket, mode, message)
  end

  defp queues_count(gossip) do
    gossip
    |> Enum.uniq_by(& &1["queue"])
    |> length()
  end
end
