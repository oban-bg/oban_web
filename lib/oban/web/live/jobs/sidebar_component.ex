defmodule Oban.Web.Jobs.SidebarComponent do
  use Oban.Web, :html

  alias Oban.Web.{JobQuery, Queue, SidebarComponents}

  attr :collapsed, :list, default: []
  attr :nodes, :list
  attr :params, :map
  attr :queues, :list
  attr :states, :list
  attr :csp_nonces, :map
  attr :width, :integer, default: 320
  attr :archive?, :boolean, default: false

  def sidebar(assigns) do
    {state_header, state_key} = state_column(assigns.params)

    assigns =
      assign(assigns,
        modes?: Enum.any?(assigns.queues, &modes?/1),
        state_header: state_header,
        state_key: state_key
      )

    ~H"""
    <SidebarComponents.sidebar label="Job filters" width={@width} csp_nonces={@csp_nonces}>
      <SidebarComponents.section
        name="states"
        headers={if @archive?, do: [], else: ["jobs"]}
        expanded={"states" not in @collapsed}
      >
        <div role="group" aria-label="Filter by one state">
          <SidebarComponents.filter_row
            :for={state <- @states}
            name={state.name}
            state={state.name}
            exclusive={true}
            active={active_filter?(@params, :state, state.name)}
            patch={state_patch(@params, state.name)}
            values={if @archive?, do: [], else: [state.count]}
          />
        </div>

        <.archive_row archive?={@archive?} params={@params} />
      </SidebarComponents.section>

      <SidebarComponents.section
        :let={labels}
        :if={not @archive?}
        name="nodes"
        headers={[%{short: "exec", label: "executing"}, "limit"]}
        expanded={"nodes" not in @collapsed}
      >
        <SidebarComponents.empty_row :if={@nodes == []} text="No nodes reporting" />

        <SidebarComponents.filter_row
          :for={node <- @nodes}
          name={node.name}
          labels={labels}
          active={active_filter?(@params, :nodes, node.name)}
          patch={patch_params(@params, :jobs, :nodes, node.name)}
          values={[node.count, node.limit]}
        >
          <:leading>
            <Icons.icon
              name="icon-computer-desktop"
              class="w-4 h-4 text-gray-400 dark:text-gray-600"
            />
          </:leading>
        </SidebarComponents.filter_row>
      </SidebarComponents.section>

      <SidebarComponents.section
        :let={labels}
        :if={not @archive?}
        name="queues"
        mode_header={if(@modes?, do: %{short: "mode", label: "Limits, partitioning, and pauses"})}
        headers={["limit", %{short: "exec", label: "executing"}, @state_header]}
        expanded={"queues" not in @collapsed}
      >
        <SidebarComponents.empty_row :if={@queues == []} text="No queues running" />

        <SidebarComponents.filter_row
          :for={queue <- @queues}
          name={queue.name}
          labels={labels}
          active={active_filter?(@params, :queues, queue.name)}
          patch={patch_params(@params, :jobs, :queues, queue.name)}
          values={[
            Queue.total_limit(queue),
            queue.counts.executing,
            Map.get(queue.counts, @state_key, 0)
          ]}
        >
          <:leading>
            <.link
              id={"queue-#{queue.name}-details"}
              patch={oban_path([:queues, queue.name])}
              aria-label={"#{queue.name} queue details"}
              data-title="Queue details"
              phx-hook="Tippy"
              class="flex items-center p-1.5 -m-1.5 rounded-sm text-gray-400 dark:text-gray-600 hover:text-violet-500 dark:hover:text-violet-400 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
            >
              <Icons.icon name="icon-queue-list" class="w-4 h-4" />
            </.link>
          </:leading>

          <:statuses :if={@modes?}>
            <.mode_icon
              :if={Queue.global_limit?(queue)}
              icon="icon-globe"
              id={"mode-#{queue.name}-global"}
              label="Global limit"
            />
            <.mode_icon
              :if={Queue.rate_limit?(queue)}
              icon="icon-arrow-trending-down"
              id={"mode-#{queue.name}-rate"}
              label="Rate limit"
            />
            <.mode_icon
              :if={Queue.partitioned?(queue)}
              icon="icon-view-columns"
              id={"mode-#{queue.name}-partition"}
              label="Partitioned"
            />
            <.mode_icon
              :if={Queue.all_paused?(queue)}
              icon="icon-pause-circle"
              id={"mode-#{queue.name}-paused"}
              label="All paused"
              class="text-amber-500 dark:text-amber-400"
            />
            <.mode_icon
              :if={Queue.any_paused?(queue) and not Queue.all_paused?(queue)}
              icon="icon-play-pause-circle"
              id={"mode-#{queue.name}-some-paused"}
              label="Some paused"
              class="text-amber-500 dark:text-amber-400"
            />
          </:statuses>
        </SidebarComponents.filter_row>
      </SidebarComponents.section>
    </SidebarComponents.sidebar>
    """
  end

  # Archived jobs live in a separate table with only finished states, so switching keeps the
  # filters and moves the state to one that exists there. The row sits with the states because
  # the archive is another place a job can be, not a filter on where it is now. Counts are never
  # queried for the archive, so the tooltip says so where the missing numbers would be noticed.
  attr :archive?, :boolean, required: true
  attr :params, :map, required: true

  defp archive_row(assigns) do
    ~H"""
    <div class="mt-1 pt-1 border-t border-gray-200 dark:border-gray-800">
      <SidebarComponents.filter_row
        name="archive"
        active={@archive?}
        patch={oban_path(:jobs, toggle_archive(@params, @archive?))}
        tooltip={archive_tooltip(@archive?)}
        values={[]}
      >
        <:leading>
          <Icons.icon
            name="icon-square-stack"
            class={[
              "w-4 h-4",
              if(@archive?,
                do: "text-violet-500 dark:text-violet-400",
                else: "text-gray-400 dark:text-gray-600"
              )
            ]}
          />
        </:leading>
      </SidebarComponents.filter_row>
    </div>
    """
  end

  defp archive_tooltip(true), do: "Back to live jobs"

  defp archive_tooltip(_archive?),
    do: "Browse archived jobs. Counts aren't tracked for the archive."

  defp toggle_archive(params, true), do: Map.delete(params, :archive)

  defp toggle_archive(params, _archive?) do
    params = Map.put(params, :archive, "true")

    if params[:state] in JobQuery.archive_states() do
      params
    else
      Map.put(params, :state, "completed")
    end
  end

  # The third queue column follows the selected state so the sidebar answers "which queue" for
  # whatever is being investigated. Executing already has a column, so it shows available instead.
  defp state_column(params) do
    case params[:state] do
      state when state in [nil, "executing"] ->
        {%{state: "available", label: "available"}, :available}

      state ->
        {%{state: state, label: state}, String.to_existing_atom(state)}
    end
  end

  defp modes?(queue) do
    Queue.global_limit?(queue) or Queue.rate_limit?(queue) or Queue.partitioned?(queue) or
      Queue.any_paused?(queue)
  end

  defp state_patch(params, name) do
    if active_filter?(params, :state, name) do
      oban_path(:jobs, params)
    else
      patch_params(params, :jobs, :state, name)
    end
  end

  attr :icon, :string, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :class, :string, default: nil

  defp mode_icon(assigns) do
    ~H"""
    <span class={["flex items-center", @class]} data-title={@label} id={@id} phx-hook="Tippy">
      <Icons.icon name={@icon} class="w-4 h-4" />
      <span class="sr-only">{@label}</span>
    </span>
    """
  end
end
