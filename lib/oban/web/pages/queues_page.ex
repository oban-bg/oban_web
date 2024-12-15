defmodule Oban.Web.QueuesPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.{Met, Notifier}
  alias Oban.Web.Queues.{DetailComponent, DetailInsanceComponent, TableComponent}
  alias Oban.Web.{Page, Telemetry}

  @flash_timing 5_000

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queues-page" class="w-full flex flex-col my-6 md:flex-row">
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
              class="flex items-center justify-between border-b border-gray-200 dark:border-gray-700 px-3 py-6"
            >
              <div class="flex space-x-2">
                <h2 class="text-lg dark:text-gray-200 leading-4 font-bold">Queues</h2>
                <h3 class="text-lg text-gray-500 leading-4 font-normal tabular">
                  ({queues_count(@checks)})
                </h3>
              </div>
              <div class="flex space-x-2">
                <.all_button
                  access={@access}
                  action="pause"
                  checks={@checks}
                  disabled={all_paused?(@checks)}
                  myself={@myself}
                >
                  <:icon><Icons.pause_circle class="w-5 h-5" /></:icon>
                </.all_button>
                <.all_button
                  access={@access}
                  action="resume"
                  checks={@checks}
                  disabled={not any_paused?(@checks)}
                  myself={@myself}
                >
                  <:icon><Icons.play_circle class="w-5 h-5" /></:icon>
                </.all_button>
              </div>
            </div>

            <.live_component
              id="queues-table"
              module={TableComponent}
              access={@access}
              counts={@counts}
              checks={@checks}
              expanded={@expanded}
              params={@params}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :action, :string, required: true
  attr :access, :any
  attr :checks, :any
  attr :disabled, :boolean, default: true
  attr :myself, :any
  slot :icon, required: true

  defp all_button(assigns) do
    ~H"""
    <button
      rel={"toggle-#{@action}"}
      class="flex items-center space-x-2 p-2 text-sm bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-200
      border border-gray-300 dark:border-gray-700 rounded-md
      focus:outline-none hover:text-blue-500 hover:border-blue-500 dark:hover:border-blue-500
      disabled:text-gray-300 disabled:border-gray-200 dark:disabled:text-gray-600 dark:disabled:border-gray-700"
      data-title={"#{String.capitalize(@action)} all queues"}
      disabled={@disabled or not can?(:pause_queues, @access)}
      id={"toggle-#{@action}-all"}
      type="button"
      phx-click={"toggle-#{@action}-all"}
      phx-target={@myself}
      phx-hook="Tippy"
    >
      <span>{String.capitalize(@action)} All</span>
      {render_slot(@icon)}
    </button>
    """
  end

  @impl Page
  def handle_mount(socket) do
    default = fn -> %{sort_by: "name", sort_dir: "asc"} end

    socket
    |> assign_new(:detail, fn -> nil end)
    |> assign_new(:params, default)
    |> assign_new(:default_params, default)
    |> assign_new(:expanded, &MapSet.new/0)
    |> assign_new(:checks, fn -> checks(socket.assigns.conf) end)
    |> assign_new(:counts, fn -> counts(socket.assigns.conf) end)
  end

  @impl Page
  def handle_refresh(socket) do
    conf = socket.assigns.conf

    assign(socket, counts: counts(conf), checks: checks(conf))
  end

  defp checks(conf) do
    Met.checks(conf.name)
  end

  defp counts(conf) do
    Met.latest(conf.name, :full_count, group: "queue", filters: [state: "available"])
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
      |> Map.take(["sort_by", "sort_dir"])
      |> Map.new(fn {key, val} -> {String.to_existing_atom(key), val} end)

    socket =
      socket
      |> assign(page_title: page_title("Queues"))
      |> assign(detail: nil, params: Map.merge(socket.assigns.default_params, params))
      |> handle_refresh()

    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("toggle-pause-all", _params, socket) do
    send(self(), :toggle_pause_all)

    {:noreply, socket}
  end

  def handle_event("toggle-resume-all", _params, socket) do
    send(self(), :toggle_resume_all)

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

  def handle_info(:toggle_pause_all, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    Telemetry.action(:pause_all_queues, socket, [], fn ->
      Oban.pause_all_queues(socket.assigns.conf.name)
    end)

    {:noreply, flash(socket, :info, "All queues paused")}
  end

  def handle_info(:toggle_resume_all, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    Telemetry.action(:resume_all_queues, socket, [], fn ->
      Oban.resume_all_queues(socket.assigns.conf.name)
    end)

    {:noreply, flash(socket, :info, "All queues resumed")}
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
      for checks <- socket.assigns.checks do
        send_update(DetailInsanceComponent, id: node_name(checks), local_limit: opts[:limit])
      end
    end

    {:noreply, flash(socket, :info, scale_message(queue, opts))}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # Socket Helpers

  defp flash(socket, mode, message) do
    Process.send_after(self(), :clear_flash, @flash_timing)

    put_flash(socket, mode, message)
  end

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

  defp queues_count(checks) do
    checks
    |> Enum.uniq_by(& &1["queue"])
    |> length()
  end

  defp all_paused?(checks), do: Enum.all?(checks, & &1["paused"])

  defp any_paused?(checks), do: Enum.any?(checks, & &1["paused"])
end
