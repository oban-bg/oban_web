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
          patch={patch(@params, :is, "paused")}
          values={[count(@queues, :paused)]}
          active={active?(@params, :is, :paused)}
        />
        <SidebarComponents.filter_row
          name="terminating"
          patch={patch(@params, :is, "terminating")}
          values={[count(@queues, :terminating)]}
          active={active?(@params, :is, :terminating)}
        />
      </SidebarComponents.section>

      <SidebarComponents.section name="limits" headers={~w(count)}>
        <SidebarComponents.filter_row
          name="global"
          patch={patch(@params, :is, "global")}
          values={[count(@queues, :global_limit)]}
          active={active?(@params, :is, :global)}
        />
        <SidebarComponents.filter_row
          name="rate-limited"
          patch={patch(@params, :is, "rate_limit")}
          values={[count(@queues, :rate_limit)]}
          active={active?(@params, :is, :rate_limit)}
        />
      </SidebarComponents.section>

      <SidebarComponents.section name="nodes" headers={~w(count)}>
        <SidebarComponents.filter_row
          :for={{node, count} <- nodes(@queues)}
          name={node}
          patch={patch(@params, :nodes, node)}
          values={[count]}
          active={active?(@params, :nodes, node)}
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

  defp patch(params, key, value) do
    param_value = params[key]

    params =
      cond do
        value == param_value or [value] == param_value ->
          Map.delete(params, key)

        is_list(param_value) and value in param_value ->
          Map.put(params, key, List.delete(param_value, value))

        is_list(param_value) ->
          Map.put(params, key, [value | param_value])

        true ->
          Map.put(params, key, value)
      end

    oban_path(:queues, params)
  end

  defp active?(params, key, status) do
    params
    |> Map.get(key, [])
    |> List.wrap()
    |> Enum.member?(to_string(status))
  end
end
