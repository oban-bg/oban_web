defmodule Oban.Web.Live.Sidebar do
  use Oban.Web, :live_component

  import Oban.Web.Helpers.SidebarHelper

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="sidebar" class="mr-3 mt-4">
      <%= if :nodes in @sections do %>
        <.section id="nodes" name="Nodes" headers={~w(Exec Limit)}>
          <%= for node <- nodes(@conf.name) do %>
            <.node_row node={node} page={@page} params={@params} socket={@socket} />
          <% end %>
        </.section>
      <% end %>

      <%= if :states in @sections do %>
        <.section id="states" name="States" headers={~w(Count)}>
          <%= for state <- states(@conf.name) do %>
            <.state_row state={state} page={@page} params={@params} socket={@socket} />
          <% end %>
        </.section>
      <% end %>

      <%= if :queues in @sections do %>
        <.section id="queues" name="Queues" headers={~w(Mode Limit Exec Avail)}>
          <%= for queue <- queues(@conf.name) do %>
            <.queue_row queue={queue} page={@page} params={@params} socket={@socket} />
          <% end %>
        </.section>
      <% end %>
    </div>
    """
  end

  defp section(assigns) do
    ~H"""
    <div
      id={@id}
      class="bg-transparent dark:bg-transparent w-fill mb-3 rounded-md overflow-hidden md:w-84"
    >
      <header class="group flex justify-between items-center border-b border-gray-300 dark:border-gray-700 px-3 py-3">
        <span class="dark:text-gray-200 font-bold"><%= @name %></span>

        <div class="flex group-hover:hidden">
          <%= for header <- @headers do %>
            <div class="text-xs text-gray-600 dark:text-gray-400 uppercase text-right w-10">
              <%= header %>
            </div>
          <% end %>
        </div>

        <div class="hidden group-hover:block">
          <button
            id={"#{@id}-toggle"}
            class="block w-5 h-5 text-gray-400 hover:text-blue-500 dark:text-gray-600 dark:hover:text-blue-500"
            data-title={"Toggle #{@name}"}
            phx-click={toggle(@id)}
            phx-hook="Tippy"
          >
            <Icons.minus_circle id={"#{@id}-hide-icon"} class="w-6 h-6 block" />
            <Icons.plus_circle id={"#{@id}-show-icon"} class="w-6 h-6 hidden" />
          </button>
        </div>
      </header>

      <div id={"#{@id}-rows"}>
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  defp node_row(assigns) do
    active_class =
      if assigns.node.name in List.wrap(assigns.params[:nodes]),
        do: "border-blue-500",
        else: "border-transparent"

    assigns = assign(assigns, active_class: active_class)

    ~H"""
    <%= live_patch(
        to: filter_link(@page, :nodes, @node.name, @params),
        replace: true,
        id: "node-#{sanitize_name(@node.name)}",
        rel: "filter",
        class: "flex justify-between py-2.5 border-l-4 hover:bg-gray-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-10 focus:bg-gray-50 dark:focus:bg-blue-300 dark:focus:bg-opacity-10 #{@active_class}") do %>
      <span class="pl-2 text-sm text-gray-700 dark:text-gray-300 text-left font-semibold truncate">
        <%= String.downcase(@node.name) %>
      </span>
      <div class="flex-none">
        <span class="pr-3 text-sm text-gray-600 dark:text-gray-400 text-right tabular">
          <%= integer_to_estimate(@node.count) %>
        </span>
        <span class="pr-3 text-sm text-gray-600 dark:text-gray-400 text-right w-10 tabular">
          <%= integer_to_estimate(@node.limit) %>
        </span>
      </div>
    <% end %>
    """
  end

  defp state_row(assigns) do
    active_class =
      if assigns.params[:state] == assigns.state.name or
           (is_nil(assigns.params[:state]) and assigns.state.name == "executing"),
         do: "border-blue-500",
         else: "border-transparent"

    params =
      if assigns.state.name in ["available", "scheduled"] do
        Map.delete(assigns.params, :nodes)
      else
        assigns.params
      end

    params =
      if assigns.state.name in ["executing", "cancelled", "completed", "discarded"] do
        Map.put(params, :sort_dir, "desc")
      else
        Map.put(params, :sort_dir, "asc")
      end

    assigns = assign(assigns, active_class: active_class, params: params)

    ~H"""
    <%= live_patch(
        to: filter_link(@page, :state, @state.name, @params),
        replace: true,
        id: "state-#{@state.name}",
        rel: "filter",
        class: "flex justify-between py-2.5 border-l-4 hover:bg-gray-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-10 focus:bg-gray-50 dark:focus:bg-blue-300 dark:focus:bg-opacity-10 #{@active_class}") do %>
      <span class="pl-2 text-sm text-gray-700 dark:text-gray-300 text-left font-semibold truncate">
        <%= @state.name %>
      </span>
      <span class="pr-3 text-sm text-gray-600 dark:text-gray-400 text-right tabular">
        <%= integer_to_estimate(@state.count) %>
      </span>
    <% end %>
    """
  end

  defp queue_row(assigns) do
    active_class =
      if assigns.queue.name in List.wrap(assigns.params[:queues]),
        do: "border-blue-500",
        else: "border-transparent"

    assigns = assign(assigns, active_class: active_class)

    ~H"""
    <%= live_patch(
        to: filter_link(@page, :queues, @queue.name, @params),
        replace: true,
        id: "queue-#{@queue.name}",
        rel: "filter",
        class: "flex justify-between py-2.5 border-l-4 hover:bg-gray-50 dark:hover:bg-blue-300 dark:hover:bg-opacity-10 focus:bg-gray-50 dark:focus:bg-blue-300 dark:focus:bg-opacity-10 #{@active_class}") do %>
      <span class={"pl-2 text-sm text-gray-700 dark:text-gray-300 text-left font-semibold truncate #{if @queue.paused?, do: "line-through font-light"}"}>
        <%= @queue.name %>
      </span>

      <div class="pr-3 flex items-center flex-none text-gray-600 dark:text-gray-400">
        <div class="flex items-center text-right">
          <%= if @queue.paused? do %>
            <span title="Paused" rel="is-paused">
              <Icons.pause_circle class="w-4 h-4" />
            </span>
          <% end %>

          <%= if @queue.rate_limited? do %>
            <span title="Rate Limited" rel="is-rate-limited">
              <Icons.arrow_trending_down class="w-4 h-4" />
            </span>
          <% end %>

          <%= if @queue.global? do %>
            <span title="Global" rel="is-global">
              <Icons.globe class="w-4 h-4" />
            </span>
          <% end %>

          <div class="text-sm w-10 tabular" rel="limit"><%= integer_to_estimate(@queue.limit) %></div>
        </div>
        <div class="text-sm text-right w-10 tabular" rel="executing">
          <%= integer_to_estimate(@queue.execu) %>
        </div>
        <div class="text-sm text-right w-10 tabular" rel="available">
          <%= integer_to_estimate(@queue.avail) %>
        </div>
      </div>
    <% end %>
    """
  end

  # Helpers

  defp filter_link(page, key, value, params) do
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

    oban_path(page, params)
  end

  defp toggle(prefix) do
    JS.toggle(to: "##{prefix}-hide-icon")
    |> JS.toggle(to: "##{prefix}-show-icon")
    |> JS.toggle(to: "##{prefix}-rows")
  end

  defp sanitize_name(name) do
    name
    |> String.downcase()
    |> String.replace("/", "_")
  end
end
