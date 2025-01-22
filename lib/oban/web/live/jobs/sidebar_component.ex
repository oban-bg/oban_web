defmodule Oban.Web.Jobs.SidebarComponent do
  use Oban.Web, :html

  alias Oban.Web.Queue
  alias Oban.Web.SidebarComponents

  attr :nodes, :list
  attr :params, :map
  attr :queues, :list
  attr :states, :list

  def sidebar(assigns) do
    ~H"""
    <SidebarComponents.sidebar>
      <SidebarComponents.section name="states" headers={~w(count)}>
        <SidebarComponents.filter_row
          :for={state <- @states}
          name={state.name}
          exclusive={true}
          active={active_filter?(@params, :state, state.name)}
          patch={patch_params(@params, :jobs, :state, state.name)}
          values={[state.count]}
        />
      </SidebarComponents.section>

      <SidebarComponents.section name="nodes" headers={~w(exec limit)}>
        <SidebarComponents.filter_row
          :for={node <- @nodes}
          name={node.name}
          active={active_filter?(@params, :nodes, node.name)}
          patch={patch_params(@params, :jobs, :nodes, node.name)}
          values={[node.limit, node.count]}
        />
      </SidebarComponents.section>

      <SidebarComponents.section name="queues" headers={~w(mode limit exec avail)}>
        <SidebarComponents.filter_row
          :for={queue <- @queues}
          name={queue.name}
          active={active_filter?(@params, :queues, queue.name)}
          patch={patch_params(@params, :jobs, :queues, queue.name)}
          values={[Queue.total_limit(queue), queue.counts.executing, queue.counts.available]}
        >
          <:statuses>
            <Icons.arrow_trending_down
              :if={Queue.rate_limit?(queue)}
              class="w-4 h-4"
              data-title="Rate limited"
              id={"#{queue.name}-is-rate-limited"}
              phx-hook="Tippy"
              rel="is-rate-limited"
            />
            <Icons.globe
              :if={Queue.global_limit?(queue)}
              class="w-4 h-4"
              data-title="Globally limited"
              id={"#{queue.name}-is-global"}
              phx-hook="Tippy"
              rel="is-global"
            />
            <Icons.pause_circle
              :if={Queue.all_paused?(queue)}
              class="w-4 h-4"
              data-title="All paused"
              id={"#{queue.name}-is-paused"}
              phx-hook="Tippy"
              rel="is-paused"
            />
            <Icons.play_pause_circle
              :if={Queue.any_paused?(queue) and not Queue.all_paused?(queue)}
              class="w-4 h-4"
              data-title="Some paused"
              id={"#{queue.name}-is-some-paused"}
              phx-hook="Tippy"
              rel="has-some-paused"
            />
          </:statuses>
        </SidebarComponents.filter_row>
      </SidebarComponents.section>
    </SidebarComponents.sidebar>
    """
  end
end
