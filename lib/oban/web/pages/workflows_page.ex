defmodule Oban.Web.WorkflowsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Web.{Page, SearchComponent, SortComponent, WorkflowQuery}
  alias Oban.Web.Workflows.TableComponent

  @known_params ~w(ids limit names queues sort_by sort_dir states workers)

  @inc_limit 10
  @max_limit 100
  @min_limit 10

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="workflows-page" class="w-full my-6">
      <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
        <div
          id="workflows-header"
          class="pr-3 py-3 flex items-center border-b border-gray-200 dark:border-gray-700"
        >
          <div class="flex-none flex items-center px-3">
            <h2 class="text-lg dark:text-gray-200 leading-4 font-bold">Workflows</h2>
          </div>

          <.live_component
            conf={@conf}
            id="search"
            module={SearchComponent}
            page={:workflows}
            params={without_defaults(@params, @default_params)}
            queryable={WorkflowQuery}
            resolver={@resolver}
          />

          <div class="pl-3 ml-auto flex items-center">
            <SortComponent.select
              id="workflows-sort"
              by={~w(inserted started duration total progress)}
              page={:workflows}
              params={@params}
            />
          </div>
        </div>

        <.live_component
          id="workflows-table"
          module={TableComponent}
          workflows={@workflows}
          expanded={@expanded}
          sub_workflows={@sub_workflows}
        />

        <div
          :if={@show_less? or @show_more?}
          class="py-6 flex items-center justify-center space-x-6 border-t border-gray-200 dark:border-gray-700"
        >
          <.load_button label="Show Less" click="load-less" active={@show_less?} myself={@myself} />
          <.load_button label="Show More" click="load-more" active={@show_more?} myself={@myself} />
        </div>
      </div>
    </div>
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

  defp loader_class(_), do: "text-gray-400 dark:text-gray-500 cursor-not-allowed"

  @impl Page
  def handle_mount(socket) do
    default = %{limit: @min_limit, sort_by: "inserted", sort_dir: "desc"}

    socket
    |> assign(:default_params, default)
    |> assign_new(:params, fn -> default end)
    |> assign_new(:workflows, fn -> [] end)
    |> assign_new(:show_less?, fn -> false end)
    |> assign_new(:show_more?, fn -> false end)
    |> assign_new(:expanded, fn -> MapSet.new() end)
    |> assign_new(:sub_workflows, fn -> %{} end)
  end

  @impl Page
  def handle_refresh(socket) do
    %{params: params, conf: conf} = socket.assigns

    workflows = WorkflowQuery.all_workflows(params, conf)
    limit = params.limit

    assign(socket,
      workflows: workflows,
      show_less?: limit > @min_limit,
      show_more?: limit < @max_limit and length(workflows) == limit
    )
  end

  @impl Page
  def handle_params(params, _uri, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params()

    socket =
      socket
      |> assign(page_title: page_title("Workflows"))
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

  def handle_event("toggle-subs", %{"id" => workflow_id}, socket) do
    %{expanded: expanded, sub_workflows: sub_workflows, conf: conf} = socket.assigns

    socket =
      if MapSet.member?(expanded, workflow_id) do
        assign(socket, expanded: MapSet.delete(expanded, workflow_id))
      else
        sub_workflows =
          if Map.has_key?(sub_workflows, workflow_id) do
            sub_workflows
          else
            subs = WorkflowQuery.get_sub_workflows(conf, workflow_id)
            Map.put(sub_workflows, workflow_id, subs)
          end

        assign(socket, expanded: MapSet.put(expanded, workflow_id), sub_workflows: sub_workflows)
      end

    {:noreply, socket}
  end

  @impl Page
  def handle_info({:params, :limit, inc}, socket) when is_integer(inc) do
    params =
      socket.assigns.params
      |> Map.update!(:limit, &(&1 + inc))
      |> without_defaults(socket.assigns.default_params)

    {:noreply, push_patch(socket, to: oban_path(:workflows, params), replace: true)}
  end

  def handle_info(:refresh, socket) do
    {:noreply, handle_refresh(socket)}
  end

  def handle_info(_event, socket) do
    {:noreply, socket}
  end
end
