defmodule Oban.Web.Queues.SidebarComponent do
  use Oban.Web, :html

  alias Oban.Web.Queue
  alias Oban.Web.SidebarComponents

  attr :queues, :list
  attr :params, :map

  def sidebar(assigns) do
    ~H"""
    <SidebarComponents.sidebar>
      <SidebarComponents.section name="stats" headers={~w(count)}>
        <SidebarComponents.filter_row
          name="paused"
          active={active_filter?(@params, :stats, :paused)}
          patch={patch_params(@params, :queues, :stats, :paused)}
          values={[Enum.count(@queues, &Queue.any_paused?/1)]}
        />
        <SidebarComponents.filter_row
          name="terminating"
          active={active_filter?(@params, :stats, :terminating)}
          patch={patch_params(@params, :queues, :stats, :terminating)}
          values={[Enum.count(@queues, &Queue.terminating?/1)]}
        />
      </SidebarComponents.section>

      <SidebarComponents.section name="modes" headers={~w(count)}>
        <SidebarComponents.filter_row
          name="global-limit"
          active={active_filter?(@params, :modes, :global_limit)}
          patch={patch_params(@params, :queues, :modes, :global_limit)}
          values={[Enum.count(@queues, &Queue.global_limit?/1)]}
        />
        <SidebarComponents.filter_row
          name="rate-limit"
          active={active_filter?(@params, :modes, :rate_limit)}
          patch={patch_params(@params, :queues, :modes, :rate_limit)}
          values={[Enum.count(@queues, &Queue.rate_limit?/1)]}
        />
      </SidebarComponents.section>

      <SidebarComponents.section name="nodes" headers={~w(count)}>
        <SidebarComponents.filter_row
          :for={{node, count} <- nodes(@queues)}
          name={node}
          active={active_filter?(@params, :nodes, node)}
          patch={patch_params(@params, :queues, :nodes, node)}
          values={[count]}
        />
      </SidebarComponents.section>
    </SidebarComponents.sidebar>
    """
  end

  defp nodes(queues) do
    queues
    |> Enum.flat_map(& &1.checks)
    |> Enum.reduce(%{}, fn %{"node" => node}, acc -> Map.update(acc, node, 1, &(&1 + 1)) end)
  end
end
