defmodule Oban.Web.Queues.SidebarComponent do
  use Oban.Web, :html

  alias Oban.Web.SidebarComponents

  attr :queues, :list
  attr :params, :map

  def sidebar(assigns) do
    ~H"""
    <SidebarComponents.sidebar>
      <SidebarComponents.section name="statuses" headers={~w(count)}>
        <SidebarComponents.filter_row
          name="paused"
          active={active_filter?(@params, :is, :paused)}
          patch={patch_params(@params, :queues, :is, "paused")}
          values={[count(@queues, :paused)]}
        />
        <SidebarComponents.filter_row
          name="terminating"
          active={active_filter?(@params, :is, :terminating)}
          patch={patch_params(@params, :queues, :is, "terminating")}
          values={[count(@queues, :terminating)]}
        />
      </SidebarComponents.section>

      <SidebarComponents.section name="limits" headers={~w(count)}>
        <SidebarComponents.filter_row
          name="global"
          active={active_filter?(@params, :is, :global)}
          patch={patch_params(@params, :queues, :is, "global")}
          values={[count(@queues, :global_limit)]}
        />
        <SidebarComponents.filter_row
          name="rate-limited"
          active={active_filter?(@params, :is, :rate_limit)}
          patch={patch_params(@params, :queues, :is, "rate_limit")}
          values={[count(@queues, :rate_limit)]}
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

  defp count(queues, :paused) do
    Enum.count(queues, fn %{checks: checks} -> Enum.any?(checks, & &1["paused"]) end)
  end

  defp count(queues, :global_limit) do
    Enum.count(queues, fn %{checks: checks} -> Enum.any?(checks, &is_map(&1["global_limit"])) end)
  end

  defp count(queues, :rate_limit) do
    Enum.count(queues, fn %{checks: checks} -> Enum.any?(checks, &is_map(&1["rate_limit"])) end)
  end

  defp count(queues, :terminating) do
    Enum.count(queues, fn %{checks: checks} -> Enum.any?(checks, & &1["shutdown_started_at"]) end)
  end
end
