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
          values={[node.count, node.limit]}
        />
      </SidebarComponents.section>

      <SidebarComponents.section name="queues" headers={~w(mode limit exec avail)}>
        <SidebarComponents.filter_row
          :for={queue <- @queues}
          name={queue.name}
          active={active_filter?(@params, :queues, queue.name)}
          patch={patch_params(@params, :jobs, :queues, queue.name)}
          values={[Queue.total_limit(queue), queue.counts.executing, queue.counts.available]}
        />
      </SidebarComponents.section>
    </SidebarComponents.sidebar>
    """
  end
end
