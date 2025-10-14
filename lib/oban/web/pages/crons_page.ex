defmodule Oban.Web.CronsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Web.Crons.DetailComponent
  alias Oban.Web.{Cron, CronQuery, Page, SearchComponent, SortComponent}

  @known_params ~w(modes sort_by sort_dir states workers)

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="crons-page" class="w-full flex flex-col my-6 md:flex-row">
      <div class="bg-white dark:bg-gray-900 flex-grow rounded-md shadow-lg overflow-hidden">
        <%= if @detailed do %>
          <.live_component
            id="detail"
            access={@access}
            cron={@detailed}
            module={DetailComponent}
            params={without_defaults(Map.delete(@params, "id"), @default_params)}
            resolver={@resolver}
          />
        <% else %>
          <div
            id="crons-header"
            class="pr-3 flex items-center border-b border-gray-200 dark:border-gray-700"
          >
            <div class="flex-none flex items-center pr-12">
              <Core.all_checkbox click="toggle-select-all" checked={:none} myself={@myself} />

              <h2 class="text-lg dark:text-gray-200 leading-4 font-bold">Crons</h2>
            </div>

            <.live_component
              conf={@conf}
              id="search"
              module={SearchComponent}
              page={:crons}
              params={without_defaults(@params, @default_params)}
              queryable={CronQuery}
              resolver={@resolver}
            />

            <div class="pl-3 ml-auto">
              <SortComponent.select
                id="crons-sort"
                by={~w(worker schedule last_run next_run)}
                page={:crons}
                params={@params}
              />
            </div>
          </div>

          <div id="crons-table" class="min-w-full">
            <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-600">
              <.header label="name" class="ml-12 w-1/3 text-left" />
              <div class="ml-auto flex items-center space-x-6">
                <.header label="schedule" class="w-32 text-right" />
                <.header label="last run" class="w-32 text-right" />
                <.header label="next run" class="w-32 text-right" />
                <.header label="status" class="w-20 pr-3 text-right" />
              </div>
            </ul>

            <div :if={Enum.empty?(@crontab)} class="text-lg text-center py-12">
              <div class="flex items-center justify-center space-x-2 text-gray-600 dark:text-gray-300">
                <Icons.no_symbol /> <span>No crons are configured.</span>
              </div>
            </div>

            <ul class="divide-y divide-gray-100 dark:divide-gray-800">
              <.cron_row :for={cron <- @crontab} id={cron.name} cron={cron} myself={@myself} />
            </ul>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Components

  attr :label, :string, required: true
  attr :class, :string, default: ""

  defp header(assigns) do
    ~H"""
    <span class={[@class, "text-xs font-medium uppercase tracking-wider py-1.5 pl-4"]}>
      {@label}
    </span>
    """
  end

  attr :cron, Cron
  attr :id, :string
  attr :myself, :any

  defp cron_row(assigns) do
    ~H"""
    <li id={"cron-#{@id}"} class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30">
      <Core.row_checkbox click="toggle-select" value={@cron.worker} checked={false} myself={@myself} />

      <.link
        patch={oban_path([:crons, @cron.name])}
        class="py-2.5 flex flex-grow items-center cursor-pointer"
      >
        <div class="w-1/3">
          <span class="block font-semibold text-sm text-gray-700 dark:text-gray-300">
            {@cron.worker}
          </span>

          <samp class="font-mono truncate text-xs text-gray-500 dark:text-gray-400">
            {format_opts(@cron.opts)}
          </samp>
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <span class="w-32 text-right font-mono text-sm">
            {@cron.expression}
          </span>

          <span
            class="w-32 text-right text-sm"
            id={"cron-lts-#{@cron.name}"}
            data-timestamp={maybe_to_unix(@cron.last_at)}
            phx-hook="Relativize"
            phx-update="ignore"
          >
            -
          </span>

          <span
            class="w-32 text-right text-sm"
            id={"cron-nts-#{@cron.name}"}
            data-timestamp={maybe_to_unix(@cron.next_at)}
            phx-hook="Relativize"
            phx-update="ignore"
          >
            -
          </span>

          <div class="w-20 pr-3 flex justify-end items-center space-x-1">
            <Icons.sparkles
              :if={@cron.dynamic?}
              id={"cron-dynamic-icon-#{@cron.name}"}
              class="w-5 h-5"
              phx-hook="Tippy"
              data-title="Dynamic cron"
            />

            <span
              id={"cron-state-icon-#{@cron.name}"}
              phx-hook="Tippy"
              data-title={state_title(@cron)}
            >
              <.state_icon state={@cron.last_state} />
            </span>
          </div>
        </div>
      </.link>
    </li>
    """
  end

  attr :state, :string, required: true
  attr :rest, :global

  defp state_icon(assigns) do
    ~H"""
    <%= case @state do %>
      <% "available" -> %>
        <Icons.pause_circle class="w-5 h-5 text-teal-400" />
      <% "cancelled" -> %>
        <Icons.x_circle class="w-5 h-5 text-violet-400" />
      <% "completed" -> %>
        <Icons.check_circle class="w-5 h-5 text-cyan-400" />
      <% "discarded" -> %>
        <Icons.exclamation_circle class="w-5 h-5 text-rose-400" />
      <% "executing" -> %>
        <Icons.play_circle class="w-5 h-5 text-orange-400" />
      <% "retryable" -> %>
        <Icons.arrow_path class="w-5 h-5 text-yellow-400" />
      <% "scheduled" -> %>
        <Icons.play_circle class="w-5 h-5 text-emerald-400" />
      <% _ -> %>
        <Icons.minus_circle class="w-5 h-5 text-gray-400" />
    <% end %>
    """
  end

  defp state_title(cron) do
    case cron.last_state do
      nil ->
        "Unknown, no previous runs"

      state ->
        "#{String.capitalize(state)} as of #{NaiveDateTime.truncate(cron.last_at, :second)}"
    end
  end

  defp maybe_to_unix(nil), do: ""

  defp maybe_to_unix(timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  @impl Page
  def handle_mount(socket) do
    default = fn -> %{sort_by: "worker", sort_dir: "asc"} end

    socket
    |> assign_new(:default_params, default)
    |> assign_new(:detailed, fn -> nil end)
    |> assign_new(:params, default)
    |> assign_new(:crontab, fn -> [] end)
  end

  @impl Page
  def handle_refresh(socket) do
    crons = CronQuery.all_crons(socket.assigns.params, socket.assigns.conf)

    assign(socket,
      crontab: crons,
      detailed: CronQuery.refresh_cron(socket.assigns.conf, socket.assigns.detailed)
    )
  end

  @impl Page
  def handle_params(%{"id" => cron_name} = params, _uri, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params()
      |> then(&Map.merge(socket.assigns.default_params, &1))

    case CronQuery.find_cron(cron_name, socket.assigns.conf) do
      nil ->
        {:noreply, push_patch(socket, to: oban_path(:crons), replace: true)}

      cron ->
        {:noreply,
         socket
         |> assign(detailed: cron, page_title: page_title(cron.worker))
         |> assign(params: params)}
    end
  end

  def handle_params(params, _uri, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params()

    socket =
      socket
      |> assign(detailed: nil, page_title: page_title("Crons"))
      |> assign(params: Map.merge(socket.assigns.default_params, params))
      |> handle_refresh()

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

  defp format_opts(opts) when map_size(opts) == 0, do: "[]"

  defp format_opts(opts) do
    opts
    |> Enum.map_join(", ", fn {key, val} -> "#{key}: #{inspect(val)}" end)
    |> truncate(0..98)
  end
end
