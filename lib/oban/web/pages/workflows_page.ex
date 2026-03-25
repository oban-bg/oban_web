defmodule Oban.Web.WorkflowsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Pro.Workflow
  alias Oban.Web.{Page, SearchComponent, SortComponent, Telemetry, Utils, WorkflowQuery}
  alias Oban.Web.Workflows.{DetailComponent, TableComponent}

  @compile {:no_warn_undefined, Oban.Pro.Workflow}

  @known_params ~w(ids limit names queues sort_by sort_dir states workers)

  @keep_on_mount ~w(
    default_params
    detail
    sub_workflows
    graph_data
    params
    parent_workflow
    workflow
    workflows
  )a

  @inc_limit 20
  @max_limit 100
  @min_limit 20

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="workflows-page" class="w-full my-6">
      <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg overflow-hidden">
        <%= cond do %>
          <% not @has_workflows? -> %>
            <.pro_promo />
          <% @detail -> %>
            <.live_component
              id="detail"
              access={@access}
              conf={@conf}
              module={DetailComponent}
              pro_available?={@pro_available?}
              workflow={@workflow}
              parent_workflow={@parent_workflow}
              sub_workflows={@sub_workflows}
              graph_data={@graph_data}
            />
          <% true -> %>
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

            <.live_component id="workflows-table" module={TableComponent} workflows={@workflows} />

            <div
              :if={@show_less? or @show_more?}
              class="py-6 flex items-center justify-center space-x-6 border-t border-gray-200 dark:border-gray-700"
            >
              <.load_button label="Show Less" click="load-less" active={@show_less?} myself={@myself} />
              <.load_button label="Show More" click="load-more" active={@show_more?} myself={@myself} />
            </div>
        <% end %>
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

  defp pro_promo(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-16 px-6">
      <div class="flex items-center justify-center w-16 h-16 rounded-full bg-violet-100 dark:bg-violet-900/30 mb-6">
        <Icons.rectangle_group class="w-8 h-8 text-violet-500 dark:text-violet-400" />
      </div>

      <h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100 mb-3">
        Workflows
      </h2>

      <p class="text-center text-gray-600 dark:text-gray-400 max-w-3xl mb-6">
        Orchestrate jobs with dependencies for sequential execution, fan-out parallelization, and
        fan-in convergence. Build fault-tolerant processing pipelines that scale horizontally
        across all nodes.
      </p>

      <ul class="text-left text-gray-600 dark:text-gray-400 space-y-3 mb-8">
        <li class="flex items-start">
          <Icons.check class="w-5 h-5 text-violet-500 mr-2 mt-0.5 shrink-0" />
          <span>
            <span class="font-medium text-gray-700 dark:text-gray-300">Fully Distributed</span>
            — high availability and scalability across your infrastructure
          </span>
        </li>
        <li class="flex items-start">
          <Icons.check class="w-5 h-5 text-violet-500 mr-2 mt-0.5 shrink-0" />
          <span>
            <span class="font-medium text-gray-700 dark:text-gray-300">Cascading Context</span>
            — pass cumulative context between jobs for seamless data flow
          </span>
        </li>
        <li class="flex items-start">
          <Icons.check class="w-5 h-5 text-violet-500 mr-2 mt-0.5 shrink-0" />
          <span>
            <span class="font-medium text-gray-700 dark:text-gray-300">Nested Sub-Workflows</span>
            — compose hierarchically for better organization and reusability
          </span>
        </li>
      </ul>

      <.link
        href="https://oban.pro"
        target="_blank"
        class="inline-flex items-center px-5 py-2.5 rounded-lg bg-violet-600 hover:bg-violet-700 text-white font-medium transition-colors"
      >
        Learn about Oban Pro <Icons.arrow_top_right_on_square class="w-4 h-4 ml-2" />
      </.link>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) do
    default = %{limit: @min_limit, sort_by: "inserted", sort_dir: "desc"}

    assigns = Map.drop(socket.assigns, @keep_on_mount)

    %{socket | assigns: assigns}
    |> assign(:default_params, default)
    |> assign(:has_workflows?, Utils.has_workflows?(socket.assigns.conf))
    |> assign(:pro_available?, Utils.has_pro?())
    |> assign_new(:detail, fn -> nil end)
    |> assign_new(:sub_workflows, fn -> [] end)
    |> assign_new(:params, fn -> default end)
    |> assign_new(:parent_workflow, fn -> nil end)
    |> assign_new(:show_less?, fn -> false end)
    |> assign_new(:show_more?, fn -> false end)
    |> assign_new(:workflow, fn -> nil end)
    |> assign_new(:workflows, fn -> [] end)
  end

  @impl Page
  def handle_refresh(socket) do
    %{params: params, conf: conf, detail: detail, has_workflows?: has_workflows?} = socket.assigns

    cond do
      not has_workflows? ->
        socket

      detail ->
        workflow = WorkflowQuery.get_workflow(conf, detail)
        sub_workflows = WorkflowQuery.get_sub_workflows(conf, detail)
        parent_workflow = WorkflowQuery.get_sup_workflow(conf, detail)
        graph_data = WorkflowQuery.get_workflow_graph(conf, detail)

        assign(socket,
          workflow: workflow,
          sub_workflows: sub_workflows,
          parent_workflow: parent_workflow,
          graph_data: graph_data
        )

      true ->
        workflows = WorkflowQuery.all_workflows(params, conf)
        limit = params.limit

        assign(socket,
          workflows: workflows,
          show_less?: limit > @min_limit,
          show_more?: limit < @max_limit and length(workflows) == limit
        )
    end
  end

  @impl Page
  def handle_params(%{"id" => workflow_id}, _uri, socket) do
    conf = socket.assigns.conf

    workflow = WorkflowQuery.get_workflow(conf, workflow_id)
    sub_workflows = WorkflowQuery.get_sub_workflows(conf, workflow_id)
    parent_workflow = WorkflowQuery.get_sup_workflow(conf, workflow_id)
    graph_data = WorkflowQuery.get_workflow_graph(conf, workflow_id)

    title = if workflow, do: workflow.name || workflow_id, else: "Workflow"

    socket =
      assign(socket,
        detail: workflow_id,
        workflow: workflow,
        sub_workflows: sub_workflows,
        parent_workflow: parent_workflow,
        graph_data: graph_data,
        page_title: page_title(title)
      )

    {:noreply, socket}
  end

  def handle_params(params, _uri, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params()

    socket =
      socket
      |> assign(page_title: page_title("Workflows"))
      |> assign(detail: nil, params: Map.merge(socket.assigns.default_params, params))
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

    {:noreply, push_patch(socket, to: oban_path(:workflows, params), replace: true)}
  end

  def handle_info(:refresh, socket) do
    {:noreply, handle_refresh(socket)}
  end

  def handle_info({:cancel_workflow, workflow_id}, socket) do
    enforce_access!(:cancel_workflows, socket.assigns.access)

    socket =
      if Utils.has_pro?() do
        Telemetry.action(:cancel_workflow, socket, [workflow_id: workflow_id], fn ->
          Workflow.cancel_jobs(socket.assigns.conf.name, workflow_id)
        end)

        socket
        |> handle_refresh()
        |> put_flash_with_clear(:info, "Workflow jobs cancelled")
      else
        put_flash_with_clear(socket, :error, "Cancel requires Oban Pro")
      end

    {:noreply, socket}
  end

  def handle_info({:retry_workflow, workflow_id}, socket) do
    enforce_access!(:retry_workflows, socket.assigns.access)

    socket =
      if Utils.has_pro?() do
        Telemetry.action(:retry_workflow, socket, [workflow_id: workflow_id], fn ->
          Workflow.retry_jobs(socket.assigns.conf.name, workflow_id)
        end)

        socket
        |> handle_refresh()
        |> put_flash_with_clear(:info, "Workflow jobs retried")
      else
        put_flash_with_clear(socket, :error, "Retry requires Oban Pro")
      end

    {:noreply, socket}
  end

  def handle_info(_event, socket) do
    {:noreply, socket}
  end
end
