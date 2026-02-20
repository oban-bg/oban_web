defmodule Oban.Web.CronsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  import Oban.Web.Crons.Helpers, only: [maybe_to_unix: 1, state_icon: 1]

  alias Oban.Web.Crons.{DetailComponent, NewComponent}
  alias Oban.Web.{Cron, CronQuery, Page, QueueQuery, SearchComponent, SortComponent, Utils}

  @known_params ~w(limit modes names sort_by sort_dir states workers)

  @inc_limit 20
  @max_limit 100
  @min_limit 20

  @sparkline_count 60
  @sparkline_height 16
  @sparkline_bar_width 4
  @sparkline_gap 1

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="crons-page" class="w-full flex flex-col my-6 md:flex-row">
      <div class="bg-white dark:bg-gray-900 flex-grow rounded-md shadow-lg overflow-hidden">
        <%= if @detailed do %>
          <.live_component
            id="detail"
            access={@access}
            conf={@conf}
            cron={@detailed}
            history={@detailed.history}
            module={DetailComponent}
            params={without_defaults(Map.delete(@params, "id"), @default_params)}
            queues={QueueQuery.all_queues(%{}, @conf)}
            resolver={@resolver}
          />
        <% else %>
          <div
            id="crons-header"
            class="pr-3 py-3 flex items-center border-b border-gray-200 dark:border-gray-700"
          >
            <div class="flex-none flex items-center px-3">
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

            <div class="pl-3 ml-auto flex items-center">
              <SortComponent.select
                id="crons-sort"
                by={~w(name worker schedule last_run next_run)}
                page={:crons}
                params={@params}
              />

              <.link
                :if={Utils.has_dynamic_cron?(@conf)}
                patch={can?(:insert_jobs, @access) && oban_path([:crons, :new])}
                id="new-cron-button"
                data-title="Create a new dynamic cron"
                phx-hook="Tippy"
                aria-disabled={not can?(:insert_jobs, @access)}
                class={[
                  "ml-3 h-10 flex items-center text-sm bg-white dark:bg-gray-800 px-3 py-2 border rounded-md",
                  can?(:insert_jobs, @access) &&
                    "text-gray-600 dark:text-gray-400 border-gray-300 dark:border-gray-700 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 focus-visible:border-blue-500 hover:text-blue-500 hover:border-blue-600 cursor-pointer",
                  not can?(:insert_jobs, @access) &&
                    "text-gray-400 dark:text-gray-600 border-gray-200 dark:border-gray-800 cursor-not-allowed opacity-50"
                ]}
              >
                <Icons.plus_circle class="mr-1 h-4 w-4" /> New
              </.link>
            </div>
          </div>

          <div id="crons-table" class="min-w-full">
            <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-600">
              <.header label="name" class="pl-3 w-1/3 text-left" />
              <div class="ml-auto flex items-center space-x-6">
                <.header label="history" class="w-80 text-center" />
                <.header label="schedule" class="w-32 text-right" />
                <.header label="last run" class="w-32 text-right" />
                <.header label="next run" class="w-32 text-right" />
                <.header label="status" class="w-20 pr-4 text-right" />
              </div>
            </ul>

            <div :if={Enum.empty?(@crontab)} class="text-lg text-center py-12">
              <div class="flex items-center justify-center space-x-2 text-gray-600 dark:text-gray-300">
                <Icons.no_symbol /> <span>No crons are configured.</span>
              </div>
            </div>

            <ul class="divide-y divide-gray-100 dark:divide-gray-800">
              <.cron_row :for={cron <- @crontab} id={cron.name} cron={cron} />
            </ul>

            <div
              :if={@show_less? or @show_more?}
              class="py-6 flex items-center justify-center space-x-6"
            >
              <.load_button label="Show Less" click="load-less" active={@show_less?} myself={@myself} />
              <.load_button label="Show More" click="load-more" active={@show_more?} myself={@myself} />
            </div>
          </div>
        <% end %>
      </div>

      <.live_component
        :if={@show_new_form}
        id="new-cron-form"
        access={@access}
        conf={@conf}
        module={NewComponent}
        queues={QueueQuery.all_queues(%{}, @conf)}
      />
    </div>
    """
  end

  # Components

  attr :label, :string, required: true
  attr :class, :string, default: ""

  defp header(assigns) do
    ~H"""
    <span class={[@class, "text-xs font-medium uppercase tracking-wider py-1.5"]}>
      {@label}
    </span>
    """
  end

  attr :active, :boolean, required: true
  attr :click, :string, required: true
  attr :label, :string, required: true
  attr :myself, :any, required: true

  defp load_button(assigns) do
    ~H"""
    <button
      type="button"
      class={"font-semibold text-sm focus:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 #{loader_class(@active)}"}
      phx-target={@myself}
      phx-click={@click}
    >
      {@label}
    </button>
    """
  end

  defp loader_class(true) do
    """
    text-gray-700 dark:text-gray-300 cursor-pointer transition ease-in-out duration-200 border-b
    border-gray-200 dark:border-gray-800 hover:border-gray-400
    """
  end

  defp loader_class(_), do: "text-gray-400 dark:text-gray-600 cursor-not-allowed"

  attr :history, :list, required: true
  attr :id, :string, required: true

  defp sparkline(assigns) do
    history = Enum.take(assigns.history, -@sparkline_count)
    offset = @sparkline_count - length(history)

    bars =
      for {job, index} <- Enum.with_index(history) do
        x = (offset + index) * (@sparkline_bar_width + @sparkline_gap)
        %{x: x, color: state_color(job.state)}
      end

    tooltip_data =
      for job <- history do
        unix =
          (job.finished_at || job.attempted_at || job.scheduled_at)
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix(:millisecond)

        %{timestamp: unix, state: job.state}
      end

    placeholders =
      for slot <- 0..(@sparkline_count - 1) do
        %{x: slot * (@sparkline_bar_width + @sparkline_gap)}
      end

    width = @sparkline_count * (@sparkline_bar_width + @sparkline_gap)

    assigns =
      assigns
      |> assign(bars: bars, placeholders: placeholders, width: width, offset: offset)
      |> assign(height: @sparkline_height, bar_width: @sparkline_bar_width)
      |> assign(tooltip_data: tooltip_data)

    ~H"""
    <svg
      id={@id}
      width={@width}
      height={@height}
      viewBox={"0 0 #{@width} #{@height}"}
      class="flex-shrink-0 cursor-pointer"
      phx-hook="Sparkline"
      data-tooltip={Oban.JSON.encode!(@tooltip_data)}
      data-bar-width={@bar_width}
      data-offset={@offset}
    >
      <rect
        :for={placeholder <- @placeholders}
        x={placeholder.x}
        y={@height - 2}
        width={@bar_width}
        height="2"
        fill="#e5e7eb"
        class="dark:fill-gray-700"
        rx="0.5"
      />
      <rect
        :for={bar <- @bars}
        x={bar.x}
        y="0"
        width={@bar_width}
        height={@height}
        fill={bar.color}
        rx="1"
      />
    </svg>
    """
  end

  defp state_color("available"), do: "#2dd4bf"
  defp state_color("cancelled"), do: "#a78bfa"
  defp state_color("completed"), do: "#22d3ee"
  defp state_color("discarded"), do: "#fb7185"
  defp state_color("executing"), do: "#fb923c"
  defp state_color("retryable"), do: "#facc15"
  defp state_color("scheduled"), do: "#34d399"
  defp state_color(_), do: "#9ca3af"

  attr :cron, Cron
  attr :id, :string

  defp cron_row(assigns) do
    ~H"""
    <li id={"cron-#{@id}"} class="flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30">
      <.link
        patch={oban_path([:crons, @cron.name])}
        class="pl-3 py-3.5 flex flex-grow items-center cursor-pointer"
      >
        <div class="w-1/3">
          <span class="font-semibold text-sm text-gray-700 dark:text-gray-300">
            {@cron.worker}
            <span :if={show_name?(@cron)} class="font-normal text-gray-500 dark:text-gray-400">
              ({@cron.name})
            </span>
          </span>

          <div
            :if={@cron.dynamic? or has_tags?(@cron.opts) or format_opts(@cron.opts)}
            class="flex flex-wrap items-center gap-1.5 mt-1"
          >
            <span
              :if={@cron.dynamic?}
              class="inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium bg-violet-100 text-violet-700 dark:bg-violet-900/50 dark:text-violet-300"
            >
              dynamic
            </span>

            <span
              :for={tag <- get_tags(@cron.opts)}
              class="inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400"
            >
              {tag}
            </span>

            <samp
              :if={format_opts(@cron.opts)}
              class="font-mono text-xs text-gray-500 dark:text-gray-400"
            >
              {format_opts(@cron.opts)}
            </samp>
          </div>
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <div class="w-80 flex justify-center">
            <.sparkline id={"sparkline-#{@cron.name}"} history={@cron.history} />
          </div>

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

          <div class="w-20 pr-4 flex justify-end">
            <span
              id={"cron-state-icon-#{@cron.name}"}
              phx-hook="Tippy"
              data-title={state_title(@cron)}
            >
              <.state_icon state={@cron.last_state} paused={@cron.paused?} />
            </span>
          </div>
        </div>
      </.link>
    </li>
    """
  end

  defp state_title(%{paused?: true}) do
    "Paused"
  end

  defp state_title(cron) do
    case cron.last_state do
      nil ->
        "Unknown, no previous runs"

      state ->
        "#{String.capitalize(state)} as of #{NaiveDateTime.truncate(cron.last_at, :second)}"
    end
  end

  @impl Page
  def handle_mount(socket) do
    default = %{limit: @min_limit, sort_by: "worker", sort_dir: "asc"}

    socket
    |> assign(:default_params, default)
    |> assign_new(:detailed, fn -> nil end)
    |> assign_new(:params, fn -> default end)
    |> assign_new(:crontab, fn -> [] end)
    |> assign_new(:show_less?, fn -> false end)
    |> assign_new(:show_more?, fn -> false end)
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:show_new_form, fn -> false end)

    {:ok, socket}
  end

  @impl Page
  def handle_refresh(%{assigns: %{detailed: nil}} = socket) do
    %{params: params, conf: conf} = socket.assigns

    crons = CronQuery.all_crons(params, conf)
    limit = params.limit

    assign(socket,
      crontab: crons,
      show_less?: limit > @min_limit,
      show_more?: limit < @max_limit and length(crons) == limit
    )
  end

  def handle_refresh(socket) do
    %{conf: conf, detailed: detailed} = socket.assigns

    case detailed do
      %Cron{name: name} -> assign(socket, detailed: CronQuery.get_cron(name, conf))
      _ -> socket
    end
  end

  @impl Page
  def handle_params(%{"id" => "new"} = params, _uri, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params()
      |> then(&Map.merge(socket.assigns.default_params, &1))

    {:noreply,
     socket
     |> assign(detailed: nil, show_new_form: true, page_title: page_title("New Cron"))
     |> assign(params: params)}
  end

  def handle_params(%{"id" => cron_name} = params, _uri, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params()
      |> then(&Map.merge(socket.assigns.default_params, &1))

    case CronQuery.get_cron(cron_name, socket.assigns.conf) do
      nil ->
        {:noreply, push_patch(socket, to: oban_path(:crons), replace: true)}

      cron ->
        {:noreply,
         socket
         |> assign(detailed: cron, show_new_form: false, page_title: page_title(cron.worker))
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
      |> assign(detailed: nil, show_new_form: false, page_title: page_title("Crons"))
      |> assign(params: Map.merge(socket.assigns.default_params, params))
      |> handle_refresh()

    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("load-less", _params, socket) do
    if socket.assigns.show_less? do
      send(self(), {:params, :limit, -@inc_limit})
    end

    {:noreply, socket}
  end

  def handle_event("load-more", _params, socket) do
    if socket.assigns.show_more? do
      send(self(), {:params, :limit, @inc_limit})
    end

    {:noreply, socket}
  end

  @impl Page
  def handle_info({:params, :limit, inc}, socket) when is_integer(inc) do
    params =
      socket.assigns.params
      |> Map.update!(:limit, &(&1 + inc))
      |> without_defaults(socket.assigns.default_params)

    {:noreply, push_patch(socket, to: oban_path(:crons, params), replace: true)}
  end

  def handle_info({:flash, mode, message}, socket) do
    {:noreply, put_flash_with_clear(socket, mode, message)}
  end

  def handle_info(:refresh, socket) do
    {:noreply, handle_refresh(socket)}
  end

  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  defp format_opts(opts) when map_size(opts) == 0, do: nil

  defp format_opts(opts) do
    opts
    |> Map.drop(["tags"])
    |> case do
      filtered when map_size(filtered) == 0 ->
        nil

      filtered ->
        filtered
        |> Enum.map_join(", ", fn {key, val} -> "#{key}: #{inspect(val)}" end)
        |> truncate(0..98)
    end
  end

  defp has_tags?(opts), do: Map.has_key?(opts, "tags") and opts["tags"] != []

  defp get_tags(opts), do: Map.get(opts, "tags", [])

  defp show_name?(%{dynamic?: true, name: name, worker: worker}), do: name != worker

  defp show_name?(_cron), do: false
end
