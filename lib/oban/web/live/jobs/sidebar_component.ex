defmodule Oban.Web.Jobs.SidebarComponent do
  use Oban.Web, :html

  alias Oban.Web.Queue
  alias Oban.Web.SidebarComponents

  attr :nodes, :list
  attr :params, :map
  attr :queues, :list
  attr :states, :list
  attr :csp_nonces, :map
  attr :width, :integer, default: 320

  def sidebar(assigns) do
    ~H"""
    <SidebarComponents.sidebar width={@width} csp_nonces={@csp_nonces}>
      <SidebarComponents.section name="states" headers={~w(jobs)}>
        <div role="group" aria-label="Filter by one state">
          <SidebarComponents.filter_row
            :for={state <- @states}
            name={state.name}
            state={state.name}
            exclusive={true}
            active={active_filter?(@params, :state, state.name)}
            patch={state_patch(@params, state.name)}
            values={[state.count]}
          />
        </div>
      </SidebarComponents.section>

      <SidebarComponents.section name="nodes" headers={~w(exec limit)}>
        <SidebarComponents.filter_row
          :for={node <- @nodes}
          name={node.name}
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

      <SidebarComponents.section name="queues" mode_header="mode" headers={~w(limit exec avail)}>
        <SidebarComponents.filter_row
          :for={queue <- @queues}
          name={queue.name}
          active={active_filter?(@params, :queues, queue.name)}
          patch={patch_params(@params, :jobs, :queues, queue.name)}
          values={[Queue.total_limit(queue), queue.counts.executing, queue.counts.available]}
        >
          <:leading>
            <.link
              id={"queue-#{queue.name}-details"}
              patch={oban_path([:queues, queue.name])}
              aria-label={"#{queue.name} queue details"}
              data-title="Queue details"
              phx-hook="Tippy"
              class="flex items-center rounded-sm text-gray-400 dark:text-gray-600 hover:text-violet-500 dark:hover:text-violet-400 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500"
            >
              <Icons.icon name="icon-queue-list" class="w-4 h-4" />
            </.link>
          </:leading>

          <:statuses>
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
            />
            <.mode_icon
              :if={Queue.any_paused?(queue) and not Queue.all_paused?(queue)}
              icon="icon-play-pause-circle"
              id={"mode-#{queue.name}-some-paused"}
              label="Some paused"
            />
          </:statuses>
        </SidebarComponents.filter_row>
      </SidebarComponents.section>
    </SidebarComponents.sidebar>
    """
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

  defp mode_icon(assigns) do
    ~H"""
    <span class="flex items-center" data-title={@label} id={@id} phx-hook="Tippy">
      <Icons.icon name={@icon} class="w-4 h-4" />
      <span class="sr-only">{@label}</span>
    </span>
    """
  end
end
