defmodule Oban.Web.CronsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Web.{Cron, CronQuery, Page, QueueQuery, SearchComponent, SortComponent, Utils}
  alias Oban.Web.Crons.{DetailComponent, NewComponent, TableComponent}

  @known_params ~w(limit modes names sort_by sort_dir states workers)

  @inc_limit 20
  @max_limit 100
  @min_limit 20

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
                :if={Utils.has_crons?(@conf)}
                patch={can?(:insert_crons, @access) && oban_path([:crons, :new])}
                id="new-cron-button"
                data-title="Create a new dynamic cron"
                phx-hook="Tippy"
                aria-disabled={not can?(:insert_crons, @access)}
                class={[
                  "ml-3 h-10 flex items-center text-sm bg-white dark:bg-gray-800 px-3 py-2 border rounded-md",
                  can?(:insert_crons, @access) &&
                    "text-gray-600 dark:text-gray-400 border-gray-300 dark:border-gray-700 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 focus-visible:border-blue-500 hover:text-blue-500 hover:border-blue-600 cursor-pointer",
                  not can?(:insert_crons, @access) &&
                    "text-gray-400 dark:text-gray-500 border-gray-200 dark:border-gray-800 cursor-not-allowed opacity-50"
                ]}
              >
                <Icons.icon name="icon-plus-circle" class="mr-1 h-4 w-4" /> New
              </.link>
            </div>
          </div>

          <.live_component id="crons-table" module={TableComponent} crontab={@crontab} />

          <div
            :if={@show_less? or @show_more?}
            class="py-6 flex items-center justify-center space-x-6"
          >
            <.load_button label="Show Less" click="load-less" active={@show_less?} myself={@myself} />
            <.load_button label="Show More" click="load-more" active={@show_more?} myself={@myself} />
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

  defp loader_class(_), do: "text-gray-400 dark:text-gray-500 cursor-not-allowed"

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
end
