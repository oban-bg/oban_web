defmodule Oban.Web.Jobs.SidebarComponent do
  use Oban.Web, :live_component

  import Oban.Web.Helpers

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="sidebar" class="mr-3">
      <.section id="states" name="States" headers={~w(Count)}>
        <.state_row :for={state <- @states} state={state} params={@params} />
      </.section>

      <.section id="nodes" name="Nodes" headers={~w(Exec Limit)}>
        <.node_row :for={node <- @nodes} node={node} params={@params} />
      </.section>

      <.section id="queues" name="Queues" headers={~w(Mode Limit Exec Avail)}>
        <.queue_row :for={queue <- @queues} queue={queue} params={@params} />
      </.section>
    </div>
    """
  end

  slot :icon
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :headers, :list, required: true

  defp section(assigns) do
    ~H"""
    <div id={@id} class="bg-transparent dark:bg-transparent w-fill mb-3 overflow-hidden md:w-84">
      <header class="flex justify-between items-center border-b border-gray-300 dark:border-gray-700 pr-3 py-3">
        <button
          id={"#{@id}-toggle"}
          class="text-gray-400 hover:text-violet-500 dark:text-gray-600 dark:hover:text-violet-500"
          data-title={"Toggle #{@name}"}
          phx-click={toggle(@id)}
          phx-hook="Tippy"
        >
          <Icons.chevron_right class="w-5 h-5 mr-2 transition-transform rotate-90" />
        </button>

        <h3 class="dark:text-gray-200 font-bold">{@name}</h3>

        <div class="ml-auto flex text-xs text-gray-600 dark:text-gray-400 uppercase text-right">
          <span :for={header <- @headers} class=" w-10">{header}</span>
        </div>
      </header>

      <div id={"#{@id}-rows"}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  defp state_row(assigns) do
    active? =
      assigns.params[:state] == assigns.state.name or
        (is_nil(assigns.params[:state]) and assigns.state.name == "executing")

    params =
      if assigns.state.name in ["available", "scheduled"] do
        Map.delete(assigns.params, :nodes)
      else
        assigns.params
      end

    assigns = assign(assigns, active?: active?, params: params)

    ~H"""
    <.link
      id={"state-#{@state.name}"}
      patch={filter_link(:state, @state.name, @params)}
      rel="filter"
      replace={true}
      class={[
        "flex justify-between py-2 my-0.5 rounded-md border-l-4 border-transparent",
        "hover:bg-gray-100 dark:hover:bg-gray-800",
        if(@active?, do: "bg-white hover:bg-white dark:bg-gray-800 dark:hover:bg-gray-800")
      ]}
    >
      <span class={[
        "pl-2 text-sm text-gray-700 dark:text-gray-300 text-left font-medium truncate",
        if(@active?, do: "font-semibold text-gray-950 dark:text-gray-100")
      ]}>
        {@state.name}
      </span>
      <span class={[
        "pr-3 text-sm text-gray-600 dark:text-gray-400 text-right tabular",
        if(@active?, do: "text-gray-800 dark:text-gray-200")
      ]}>
        {integer_to_estimate(@state.count)}
      </span>
    </.link>
    """
  end

  defp node_row(assigns) do
    assigns = assign(assigns, active?: assigns.node.name in List.wrap(assigns.params[:nodes]))

    ~H"""
    <.link
      id={"node-#{sanitize_name(@node.name)}"}
      patch={filter_link(:nodes, @node.name, @params)}
      rel="filter"
      replace={true}
      class={[
        "flex justify-between py-2 my-0.5 border-l-4 border-transparent hover:border-violet-400 focus:border-violet-200",
        if(@active?, do: "border-violet-500 hover:border-violet-500 focus:border-violet-500")
      ]}
    >
      <span class="pl-2 text-sm text-gray-700 dark:text-gray-300 text-left tabular font-medium truncate">
        {String.downcase(@node.name)}
      </span>
      <div class="flex-none">
        <span class="pr-3 text-sm text-gray-600 dark:text-gray-400 text-right tabular">
          {integer_to_estimate(@node.count)}
        </span>
        <span class="pr-3 text-sm text-gray-600 dark:text-gray-400 text-right w-10 tabular">
          {integer_to_estimate(@node.limit)}
        </span>
      </div>
    </.link>
    """
  end

  defp queue_row(assigns) do
    assigns = assign(assigns, active?: assigns.queue.name in List.wrap(assigns.params[:queues]))

    ~H"""
    <.link
      id={"queue-#{@queue.name}"}
      patch={filter_link(:queues, @queue.name, @params)}
      rel="filter"
      replace={true}
      class={[
        "flex justify-between py-2 my-0.5 border-l-4 border-transparent hover:border-violet-400 focus:border-violet-200",
        if(@active?, do: "border-violet-500 hover:border-violet-500 focus:border-violet-500")
      ]}
    >
      <span class={[
        "pl-2 text-sm text-left font-medium truncate",
        if(@queue.any_paused?,
          do: "text-gray-400 dark:text-gray-600",
          else: "text-gray-700 dark:text-gray-300"
        )
      ]}>
        {@queue.name}
      </span>

      <div class="pr-3 flex items-center flex-none text-gray-600 dark:text-gray-400">
        <div class="flex items-center text-right space-x-1">
          <Icons.arrow_trending_down
            :if={@queue.rate_limited?}
            class="w-4 h-4"
            data-title="Rate limited"
            id={"#{@queue.name}-is-rate-limited"}
            phx-hook="Tippy"
            rel="is-rate-limited"
          />
          <Icons.globe
            :if={@queue.global?}
            class="w-4 h-4"
            data-title="Globally limited"
            id={"#{@queue.name}-is-global"}
            phx-hook="Tippy"
            rel="is-global"
          />
          <Icons.pause_circle
            :if={@queue.all_paused?}
            class="w-4 h-4"
            data-title="All paused"
            id={"#{@queue.name}-is-paused"}
            phx-hook="Tippy"
            rel="is-paused"
          />
          <Icons.play_pause_circle
            :if={@queue.any_paused? and not @queue.all_paused?}
            class="w-4 h-4"
            data-title="Some paused"
            id={"#{@queue.name}-is-some-paused"}
            phx-hook="Tippy"
            rel="has-some-paused"
          />
          <div class="text-sm w-10 tabular" rel="limit">{integer_to_estimate(@queue.limit)}</div>
        </div>
        <div class="text-sm text-right w-10 tabular" rel="executing">
          {integer_to_estimate(@queue.execu)}
        </div>
        <div class="text-sm text-right w-10 tabular" rel="available">
          {integer_to_estimate(@queue.avail)}
        </div>
      </div>
    </.link>
    """
  end

  # Component Helpers

  defp filter_link(:state, value, params) do
    oban_path(:jobs, Map.put(params, :state, value))
  end

  defp filter_link(key, value, params) do
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

    oban_path(:jobs, params)
  end

  defp toggle(prefix) do
    %JS{}
    |> JS.toggle(in: "fade-in-scale", out: "fade-out-scale", to: "##{prefix}-rows")
    |> JS.add_class("rotate-90", to: "##{prefix}-toggle svg:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "##{prefix}-toggle svg.rotate-90")
  end

  defp sanitize_name(name) do
    name
    |> String.downcase()
    |> String.replace("/", "_")
  end
end
