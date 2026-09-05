defmodule Oban.Web.WorkflowsPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Pro.Workflow
  alias Oban.Web.{Page, SearchComponent, SortComponent, Telemetry, Utils, WorkflowQuery}
  alias Oban.Web.Workflows.{DetailComponent, Helpers, TableComponent}

  @compile {:no_warn_undefined, Oban.Pro.Workflow}

  @known_params WorkflowQuery.known_params() ++ ~w(limit sort_by sort_dir)

  @keep_on_mount ~w(
    compensation
    compensation_policy
    compensation_status
    compensation_steps
    default_params
    detail
    sub_workflows
    graph_data
    origin_workflow
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
          <% not @pro_available? -> %>
            <Core.pro_promo feature="Workflows" icon="icon-rectangle-group">
              Workflows coordinate jobs with dependencies. Steps run in sequence, fan out in
              parallel, and fan back in, with context carried between steps and sub-workflows
              nested inside.
            </Core.pro_promo>
          <% not @has_workflows? -> %>
            <Core.migration_prompt
              id="workflows-migration-prompt"
              conf={@conf}
              docs="https://oban.pro/docs/pro/Oban.Pro.Workflow.html"
              feature="Workflows"
              table="oban_workflows"
              version="v1.7"
            />
          <% @detail -> %>
            <.live_component
              id="detail"
              access={@access}
              conf={@conf}
              module={DetailComponent}
              pro_available?={@pro_available?}
              workflow={@workflow}
              workflow_id={@detail}
              parent_workflow={@parent_workflow}
              origin_workflow={@origin_workflow}
              compensation={@compensation}
              compensation_policy={@compensation_policy}
              compensation_status={@compensation_status}
              compensation_steps={@compensation_steps}
              sub_workflows={@sub_workflows}
              graph_data={@graph_data}
            />
          <% true -> %>
            <div
              id="workflows-header"
              class="pr-3 py-3 flex items-center border-b border-gray-200 dark:border-gray-700"
            >
              <div class="flex-none flex items-center px-3">
                <h2 class="text-base font-semibold dark:text-gray-200">Workflows</h2>
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
              filtered?={filtered?(@params, WorkflowQuery)}
            />

            <div
              :if={@show_less? or @show_more?}
              class="py-6 flex flex-col items-center border-t border-gray-200 dark:border-gray-700"
            >
              <div class="flex items-center justify-center space-x-6">
                <.load_button
                  label="Show Less"
                  click="load-less"
                  active={@show_less?}
                  myself={@myself}
                />
                <.load_button
                  label="Show More"
                  click="load-more"
                  active={@show_more?}
                  myself={@myself}
                />
              </div>

              <p :if={@capped?} class="mt-3 text-xs text-gray-500 dark:text-gray-400">
                Showing the first {@max_limit} workflows for this sort. Add filters to find the rest.
              </p>
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
      disabled={not @active}
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

    assigns = Map.drop(socket.assigns, @keep_on_mount)

    %{socket | assigns: assigns}
    |> assign(:default_params, default)
    |> assign(:has_workflows?, Utils.has_workflows?(socket.assigns.conf))
    |> assign(:pro_available?, Utils.has_pro?())
    |> assign_new(:compensation, fn -> nil end)
    |> assign_new(:compensation_policy, fn -> [] end)
    |> assign_new(:compensation_status, fn -> :none end)
    |> assign_new(:compensation_steps, fn -> [] end)
    |> assign_new(:detail, fn -> nil end)
    |> assign_new(:sub_workflows, fn -> [] end)
    |> assign_new(:origin_workflow, fn -> nil end)
    |> assign_new(:params, fn -> default end)
    |> assign_new(:parent_workflow, fn -> nil end)
    |> assign_new(:show_less?, fn -> false end)
    |> assign_new(:show_more?, fn -> false end)
    |> assign_new(:workflow, fn -> nil end)
    |> assign_new(:workflows, fn -> [] end)
    |> assign_new(:capped?, fn -> false end)
    |> assign(:max_limit, @max_limit)
  end

  @impl Page
  def handle_refresh(socket) do
    %{params: params, conf: conf, detail: detail, has_workflows?: has_workflows?} = socket.assigns

    cond do
      not has_workflows? ->
        socket

      detail ->
        assign_detail(socket, detail)

      true ->
        workflows = WorkflowQuery.all_workflows(conf, params)
        limit = params.limit

        assign(socket,
          workflows: workflows,
          show_less?: limit > @min_limit,
          show_more?: limit < @max_limit and length(workflows) == limit,
          capped?: limit >= @max_limit and length(workflows) == limit
        )
    end
  end

  @impl Page
  def handle_params(%{"id" => workflow_id}, _uri, socket) do
    socket =
      socket
      |> assign(detail: workflow_id)
      |> assign_detail(workflow_id)

    title =
      case socket.assigns.workflow do
        %Oban.Web.Workflow{} = workflow -> Helpers.display_name(workflow)
        _workflow -> "Workflow"
      end

    {:noreply, assign(socket, page_title: page_title(title))}
  end

  def handle_params(params, _uri, socket) do
    params =
      params
      |> Map.take(@known_params)
      |> decode_params(WorkflowQuery)

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

  def handle_info({:cancel_workflow, workflow_id, name}, socket) do
    enforce_access!(:cancel_workflows, socket.assigns.access)

    socket =
      if Utils.has_pro?() do
        {:ok, count} =
          Telemetry.action(:cancel_workflow, socket, [workflow_id: workflow_id], fn ->
            Workflow.cancel_jobs(socket.assigns.conf.name, workflow_id)
          end)

        socket
        |> handle_refresh()
        |> put_flash_with_clear(:info, cancel_notice(count, name))
      else
        put_flash_with_clear(socket, :error, "Cancel requires Oban Pro")
      end

    {:noreply, socket}
  end

  def handle_info({:retry_workflow, workflow_id, name}, socket) do
    enforce_access!(:retry_workflows, socket.assigns.access)

    socket =
      if Utils.has_pro?() do
        {:ok, count} =
          Telemetry.action(:retry_workflow, socket, [workflow_id: workflow_id], fn ->
            Workflow.retry_jobs(socket.assigns.conf.name, workflow_id)
          end)

        socket
        |> handle_refresh()
        |> put_flash_with_clear(:info, retry_notice(count, name))
      else
        put_flash_with_clear(socket, :error, "Retry requires Oban Pro")
      end

    {:noreply, socket}
  end

  def handle_info(_event, socket) do
    {:noreply, socket}
  end

  defp cancel_notice(0, name), do: "Nothing left to cancel in #{name}"
  defp cancel_notice(count, name), do: "Cancelled #{count_phrase(count, "job")} in #{name}"

  defp retry_notice(0, name), do: "Nothing to retry in #{name}"
  defp retry_notice(count, name), do: "Retried #{count_phrase(count, "job")} in #{name}"

  defp count_phrase(1, noun), do: "1 #{noun}"
  defp count_phrase(count, noun), do: "#{count} #{noun}s"

  defp assign_detail(socket, workflow_id) do
    conf = socket.assigns.conf
    workflow = WorkflowQuery.get_workflow(conf, workflow_id)

    socket
    |> assign(
      workflow: workflow,
      sub_workflows: WorkflowQuery.get_sub_workflows(conf, workflow_id),
      parent_workflow: WorkflowQuery.get_sup_workflow(conf, workflow_id),
      graph_data: WorkflowQuery.get_workflow_graph(conf, workflow_id)
    )
    |> assign_compensation(workflow)
  end

  defp assign_compensation(socket, %Oban.Web.Workflow{} = workflow) do
    conf = socket.assigns.conf

    root = WorkflowQuery.get_root_workflow(conf, workflow)
    compensation = WorkflowQuery.get_compensation(conf, root)

    steps =
      case compensation do
        %Oban.Web.Workflow{id: id} -> WorkflowQuery.get_compensation_steps(conf, id)
        _compensation -> []
      end

    socket
    |> assign(
      compensation: compensation,
      compensation_policy: Helpers.compensation_policy(root),
      compensation_status: Helpers.compensation_status(root, compensation),
      compensation_steps: steps,
      origin_workflow: WorkflowQuery.get_origin(conf, workflow)
    )
    |> update(:graph_data, &Helpers.put_compensated_states(&1, steps))
  end

  defp assign_compensation(socket, _workflow) do
    assign(socket,
      compensation: nil,
      compensation_policy: [],
      compensation_status: :none,
      compensation_steps: [],
      origin_workflow: nil
    )
  end
end
