defmodule Oban.Web.Queues.DetailComponent do
  use Oban.Web, :live_component

  import Oban.Web.Components.FormComponent
  import Oban.Web.Helpers.QueueHelper

  alias Oban.Config
  alias Oban.Web.Queues.DetailInsanceComponent

  @impl Phoenix.LiveComponent
  def update(%{local_limit: new_limit}, socket) do
    %{gossip: gossip, inputs: inputs} = socket.assigns

    local_limit =
      cond do
        match?([_], gossip) ->
          new_limit

        match?([_ | _], gossip) ->
          max(local_limit(gossip), new_limit)

        true ->
          inputs.local_limit
      end

    inputs = %{inputs | local_limit: local_limit}

    {:ok, assign(socket, inputs: inputs)}
  end

  def update(assigns, socket) do
    counts = Enum.find(assigns.counts, %{}, &(&1["name"] == assigns.queue))
    gossip = Enum.filter(assigns.gossip, &(&1["queue"] == assigns.queue))

    socket =
      socket
      |> assign(access: assigns.access, conf: assigns.conf, queue: assigns.queue)
      |> assign(counts: counts, gossip: gossip)
      |> assign_new(:inputs, fn ->
        %{
          local_limit: local_limit(gossip),
          global_limit: global_limit(gossip),
          rate_limit_allowed: rate_limit_allowed(gossip),
          rate_limit_period: rate_limit_period(gossip),
          rate_limit_partition_fields: rate_limit_partition_fields(gossip),
          rate_limit_partition_keys: rate_limit_partition_keys(gossip)
        }
      end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="queue-details">
      <div class="flex justify-between items-center px-3 py-6">
        <%= live_patch to: oban_path(:queues), id: "back-link", class: "flex items-center hover:text-blue-500", "data-title": "Back to queues", "phx-hook": "Tippy" do %>
          <svg class="h-5 w-5" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd"></path></svg>
          <span class="text-lg capitalize font-bold ml-2"><%= @queue %> Queue</span>
        <% end %>
      </div>

      <table class="table-fixed w-full bg-blue-50 dark:bg-blue-300 dark:bg-opacity-25">
        <thead>
          <tr class="text-sm text-gray-600 dark:text-gray-100 dark:text-opacity-60">
            <th scope="col" class="text-left font-normal pt-6 pb-1 px-3">Started</th>
            <th scope="col" class="text-left font-normal pt-6 pb-1 px-3">Executing</th>
            <th scope="col" class="text-left font-normal pt-6 pb-1 px-3">Available</th>
            <th scope="col" class="text-left font-normal pt-6 pb-1 px-3">Scheduled</th>
            <th scope="col" class="text-left font-normal pt-6 pb-1 px-3">Retryable</th>
            <th scope="col" class="text-left font-normal pt-6 pb-1 px-3">Cancelled</th>
            <th scope="col" class="text-left font-normal pt-6 pb-1 px-3">Discarded</th>
            <th scope="col" class="text-left font-normal pt-6 pb-1 px-3">Completed</th>
          </tr>
        </thead>
        <tbody>
          <tr class="text-lg text-gray-800 dark:text-gray-100 tabular">
            <td class="pb-6 px-3">
              <div class="flex items-center space-x-2">
                <svg class="w-4 h-4 text-gray-600 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                <span><%= started_at(@gossip) %></span>
              </div>
            </td>

            <td class="pb-6 px-3">
              <div class="flex items-center space-x-2">
                <svg class="w-4 h-4 text-gray-600 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>
                <span><%= executing_count(@gossip) %></span>
              </div>
            </td>

            <%= for state <- ~w(available scheduled retryable cancelled discarded completed) do %>
              <td class="pb-6 px-3">
                <div class="flex items-center space-x-2">
                  <svg class="w-4 h-4 text-gray-600 dark:text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path></svg>
                  <span><%= integer_to_estimate(@counts[state]) %></span>
                </div>
              </td>
            <% end %>
          </tr>
        </tbody>
      </table>

      <div>
        <div class="flex items-center pl-3 py-6">
          <svg class="w-6 h-6 mr-1 text-gray-600 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M5 4a1 1 0 00-2 0v7.268a2 2 0 000 3.464V16a1 1 0 102 0v-1.268a2 2 0 000-3.464V4zM11 4a1 1 0 10-2 0v1.268a2 2 0 000 3.464V16a1 1 0 102 0V8.732a2 2 0 000-3.464V4zM16 3a1 1 0 011 1v7.268a2 2 0 010 3.464V16a1 1 0 11-2 0v-1.268a2 2 0 010-3.464V4a1 1 0 011-1z"></path></svg>
          <h3 class="font-medium text-base">Global Configuration</h3>
        </div>

        <div class="flex w-full px-3 border-t border-gray-200 dark:border-gray-700">
          <form id="local-form" class="w-1/4 pr-3 pt-3 pb-6" phx-target={@myself} phx-change="form-change" phx-submit="local-submit">
            <h3 class="flex items-center mb-4">
              <svg class="w-5 h-5 mr-1 text-gray-500" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M5.05 4.05a7 7 0 119.9 9.9L10 18.9l-4.95-4.95a7 7 0 010-9.9zM10 11a2 2 0 100-4 2 2 0 000 4z" clip-rule="evenodd"></path></svg>
              <span class="text-base font-medium">Local</span>
            </h3>

            <.number_input
              disabled={not can?(:scale_queues, @access)}
              label="Limit"
              myself={@myself}
              name="local_limit"
              value={@inputs.local_limit} />

            <.submit_input
              locked={not can?(:scale_queues, @access)}
              disabled={@inputs.local_limit == local_limit(@gossip) or not can?(:scale_queues, @access)}
              label="Scale" />
          </form>

          <form id="global-form"
                class={"relative w-1/4 px-3 pt-3 pb-6 border-l border-r border-gray-200 dark:border-gray-700 #{if missing_pro?(@conf), do: "bg-white dark:bg-black bg-opacity-30"}"}
                phx-target={@myself}
                phx-change="form-change"
                phx-submit="global-update">
            <%= if missing_pro?(@conf) do %>
              <.pro_blocker />
            <% end %>

            <div class={if missing_pro?(@conf), do: "opacity-20 cursor-not-allowed pointer-events-none select-none"}>
              <div class="flex items-center justify-between mb-4">
                <h3 class="flex items-center">
                  <svg class="w-5 h-5 mr-1 text-gray-500" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M4.083 9h1.946c.089-1.546.383-2.97.837-4.118A6.004 6.004 0 004.083 9zM10 2a8 8 0 100 16 8 8 0 000-16zm0 2c-.076 0-.232.032-.465.262-.238.234-.497.623-.737 1.182-.389.907-.673 2.142-.766 3.556h3.936c-.093-1.414-.377-2.649-.766-3.556-.24-.56-.5-.948-.737-1.182C10.232 4.032 10.076 4 10 4zm3.971 5c-.089-1.546-.383-2.97-.837-4.118A6.004 6.004 0 0115.917 9h-1.946zm-2.003 2H8.032c.093 1.414.377 2.649.766 3.556.24.56.5.948.737 1.182.233.23.389.262.465.262.076 0 .232-.032.465-.262.238-.234.498-.623.737-1.182.389-.907.673-2.142.766-3.556zm1.166 4.118c.454-1.147.748-2.572.837-4.118h1.946a6.004 6.004 0 01-2.783 4.118zm-6.268 0C6.412 13.97 6.118 12.546 6.03 11H4.083a6.004 6.004 0 002.783 4.118z" clip-rule="evenodd"></path></svg>
                  <span class="text-base font-medium">Global</span>
                </h3>

                <.toggle_button
                  disabled={not can?(:scale_queues, @access)}
                  enabled={not is_nil(@inputs.global_limit)}
                  feature="global"
                  myself={@myself} />
              </div>

              <.number_input
                disabled={not can?(:scale_queues, @access) or is_nil(@inputs.global_limit)}
                label="Limit"
                myself={@myself}
                name="global_limit"
                value={@inputs.global_limit} />

              <.submit_input
                locked={not can?(:scale_queues, @access)}
                disabled={@inputs.global_limit == global_limit(@gossip) or not can?(:scale_queues, @access)}
                label="Apply" />
            </div>
          </form>

          <form id="rate-limit-form"
                class={"relative w-1/2 pt-3 pb-6 pl-3 #{if missing_pro?(@conf), do: "bg-white dark:bg-black bg-opacity-30"}"}
                phx-target={@myself}
                phx-submit="rate-limit-update"
                phx-change="form-change">
            <%= if missing_pro?(@conf) do %>
              <.pro_blocker />
            <% end %>

            <div class={if missing_pro?(@conf), do: "opacity-20 cursor-not-allowed pointer-events-none select-none"}>
              <div class="flex items-center justify-between mb-4">
                <h3 class="flex items-center">
                  <svg class="w-5 h-5 mr-1 text-gray-600 dark:text-gray-400" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path fill-rule="evenodd" d="M12 13a1 1 0 100 2h5a1 1 0 001-1V9a1 1 0 10-2 0v2.586l-4.293-4.293a1 1 0 00-1.414 0L8 9.586 3.707 5.293a1 1 0 00-1.414 1.414l5 5a1 1 0 001.414 0L11 9.414 14.586 13H12z" clip-rule="evenodd"></path></svg>
                  <span class="text-base font-medium">Rate Limit</span>
                </h3>

                <.toggle_button
                  disabled={not can?(:scale_queues, @access)}
                  enabled={not is_nil(@inputs.rate_limit_allowed)}
                  feature="rate-limit"
                  myself={@myself} />
              </div>

              <div class="flex w-full space-x-3 mb-6">
                <div class="w-1/2">
                  <.number_input
                    disabled={not can?(:scale_queues, @access) or is_nil(@inputs.rate_limit_allowed)}
                    label="Allowed"
                    myself={@myself}
                    name="rate_limit_allowed"
                    value={@inputs.rate_limit_allowed} />
                </div>

                <div class="w-1/2">
                  <.number_input
                    disabled={not can?(:scale_queues, @access) or is_nil(@inputs.rate_limit_allowed) }
                    label="Period"
                    myself={@myself}
                    name="rate_limit_period"
                    value={@inputs.rate_limit_period} />
                </div>
              </div>

              <div class="flex w-full space-x-3">
                <div class="w-1/2">
                  <label for="rate_limit_fields" class="block font-medium text-sm mb-2">Partition Fields</label>
                  <select
                    id="rate_limit_partition_fields"
                    name="rate_limit_partition_fields"
                    class="block w-full font-mono text-sm pl-3 pr-10 py-2 shadow-sm border-gray-300 dark:border-gray-500 bg-gray-50 dark:bg-gray-800 disabled:opacity-50 rounded-md focus:outline-none focus:ring-blue-500 focus:border-blue-500"
                    disabled={not can?(:scale_queues, @access) or is_nil(@inputs.rate_limit_allowed)}>
                    <%= options_for_select(
                      ["Off": nil, "Worker": "worker", "Args": "args", "Worker + Args": "worker,args"],
                      @inputs.rate_limit_partition_fields) %>
                  </select>
                </div>

                <div class="w-1/2">
                  <label for="rate_limit_keys" class="block font-medium text-sm mb-2">Partition Keys</label>

                  <input
                    class="block w-full font-mono text-sm py-2 shadow-sm border-gray-300 dark:border-gray-500 bg-gray-50 dark:bg-gray-800 disabled:opacity-50 rounded-md focus:ring-blue-400 focus:border-blue-400"
                    disabled={not can?(:scale_queues, @access) or @inputs.rate_limit_partition_fields not in ["args", "worker,args"]}
                    id="rate_limit_partition_keys"
                    name="rate_limit_partition_keys"
                    type="text"
                    value={@inputs.rate_limit_partition_keys } />
                </div>
              </div>

              <.submit_input
                locked={not can?(:scale_queues, @access)}
                disabled={rate_limit_unchanged?(@gossip, @inputs) or not can?(:scale_queues, @access)}
                label="Apply" />
            </div>
          </form>
        </div>
      </div>

      <div id="queue-instances" class="border-t border-gray-200 dark:border-gray-700">
        <div class="flex items-center pl-3 py-6">
          <svg class="w-6 h-6 mr-1 text-gray-600 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"></path></svg>
          <h3 class="font-medium text-base">Instances</h3>
        </div>

        <table class="table-fixed min-w-full divide-y divide-gray-200 dark:divide-gray-700 border-t border-gray-200 dark:border-gray-700">
          <thead>
            <tr class="bg-gray-50 dark:bg-gray-950 text-gray-500 dark:text-gray-500">
              <th scope="col" class="w-1/2 text-left text-xs font-medium uppercase tracking-wider pl-3 py-3">Node/Name</th>
              <th scope="col" class="w-12 text-right text-xs font-medium uppercase tracking-wider py-3">Executing</th>
              <th scope="col" class="w-16 text-right text-xs font-medium uppercase tracking-wider py-3">Started</th>
              <th scope="col" class="w-8 text-left text-xs font-medium uppercase tracking-wider pl-6 py-3">Pause</th>
              <th scope="col" class="w-32 text-left text-xs font-medium uppercase tracking-wider pr-3 py-3">Scale</th>
            </tr>
          </thead>

          <tbody class="divide-y divide-gray-100 dark:divide-gray-800">
            <%= for gossip <- @gossip do %>
              <.live_component
                access={@access}
                gossip={gossip}
                id={node_name(gossip)}
                module={DetailInsanceComponent} />
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # Handlers

  @integer_inputs ~w(local_limit global_limit_allowed rate_limit_allowed rate_limit_period)

  @impl Phoenix.LiveComponent
  def handle_event("form-change", %{"_target" => "rate_limit_partition_fields"} = params, socket) do
    fields = params["rate_limit_partition_fields"]
    inputs = %{socket.assigns.inputs | rate_limit_partition_fields: fields}

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("form-change", params, socket) do
    inputs =
      for {key, val} <- params, key in @integer_inputs, reduce: socket.assigns.inputs do
        acc ->
          case Integer.parse(val) do
            {int, _} when int > 0 ->
              %{acc | String.to_existing_atom(key) => int}

            _ ->
              acc
          end
      end

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("local-submit", params, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    limit = String.to_integer(params["local_limit"])

    send(self(), {:scale_queue, socket.assigns.queue, limit: limit})

    inputs = %{socket.assigns.inputs | local_limit: limit}

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("global-update", params, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    limit = String.to_integer(params["global_limit"])

    send(self(), {:scale_queue, socket.assigns.queue, global_limit: %{allowed: limit}})

    inputs = %{socket.assigns.inputs | global_limit: limit}

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("rate-limit-update", params, socket) do
    enforce_access!(:scale_queues, socket.assigns.access)

    inputs =
      if is_nil(params["rate_limit_allowed"]) do
        send(self(), {:scale_queue, socket.assigns.queue, rate_limit: nil})

        socket.assigns.inputs
        |> Map.replace!(:rate_limit_allowed, nil)
        |> Map.replace!(:rate_limit_period, nil)
        |> Map.replace!(:rate_limit_partition_fields, nil)
        |> Map.replace!(:rate_limit_partition_keys, nil)
      else
        allowed = params["rate_limit_allowed"]
        period = params["rate_limit_period"]
        fields = maybe_split(params["rate_limit_partition_fields"])
        keys = maybe_split(params["rate_limit_partition_keys"])

        rate_limit =
          case fields do
            [] ->
              %{allowed: allowed, period: period}

            ["worker"] ->
              %{allowed: allowed, period: period, partition: [fields: fields]}

            _ ->
              %{allowed: allowed, period: period, partition: [fields: fields, keys: keys]}
          end

        send(self(), {:scale_queue, socket.assigns.queue, rate_limit: rate_limit})

        socket.assigns.inputs
        |> Map.replace!(:rate_limit_allowed, allowed)
        |> Map.replace!(:rate_limit_period, period)
        |> Map.replace!(:rate_limit_partition_fields, Enum.join(fields, ","))
        |> Map.replace!(:rate_limit_partition_keys, Enum.join(keys, ","))
      end

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("increment", %{"field" => field}, socket) do
    {:noreply, change_input(socket, field, 1)}
  end

  def handle_event("decrement", %{"field" => field}, socket) do
    {:noreply, change_input(socket, field, -1)}
  end

  def handle_event("toggle-feature", %{"feature" => "global"}, socket) do
    inputs =
      Map.update!(socket.assigns.inputs, :global_limit, fn value ->
        if is_nil(value), do: socket.assigns.inputs.local_limit, else: nil
      end)

    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("toggle-feature", %{"feature" => "rate-limit"}, socket) do
    inputs =
      if is_nil(socket.assigns.inputs.rate_limit_allowed) do
        socket.assigns.inputs
        |> Map.put(:rate_limit_allowed, socket.assigns.inputs.local_limit)
        |> Map.put(:rate_limit_period, 60)
      else
        socket.assigns.inputs
        |> Map.put(:rate_limit_allowed, nil)
        |> Map.put(:rate_limit_period, nil)
        |> Map.put(:rate_limit_partition_fields, nil)
        |> Map.put(:rate_limit_partition_keys, nil)
      end

    {:noreply, assign(socket, inputs: inputs)}
  end

  # Components

  defp toggle_button(assigns) do
    ~H"""
    <button
      class="bg-gray-200 dark:bg-gray-800 relative inline-flex flex-shrink-0 h-6 w-11 border-2 border-transparent rounded-full cursor-pointer transition-colors ease-in-out duration-200 focus:outline-none focus:ring-2 focus:ring-blue-500" role="switch" aria-checked="false"
      disabled={@disabled}
      id={"toggle-#{@feature}"}
      phx-target={@myself}
      phx-click="toggle-feature"
      phx-value-feature={@feature}
      type="button">
      <span class={"#{if @enabled, do: "translate-x-5", else: "translate-x-0"} pointer-events-none relative inline-block h-5 w-5 rounded-full bg-white shadow transform ring-0 transition ease-in-out duration-200"}>
        <span class={"#{if @enabled, do: "opacity-0 ease-out duration-100", else: "opacity-100 ease-in duration-200"} absolute inset-0 h-full w-full flex items-center justify-center transition-opacity"} aria-hidden="true">
          <svg class="h-3 w-3 text-gray-400" fill="none" viewBox="0 0 12 12">
            <path d="M4 8l2-2m0 0l2-2M6 6L4 4m2 2l2 2" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </span>
        <span class={"#{if @enabled, do: "opacity-100 ease-in duration-200", else: "opacity-0 ease-out duration-100"} absolute inset-0 h-full w-full flex items-center justify-center transition-opacity"} aria-hidden="true">
          <svg class="h-3 w-3 text-blue-500" fill="currentColor" viewBox="0 0 12 12">
            <path d="M3.707 5.293a1 1 0 00-1.414 1.414l1.414-1.414zM5 8l-.707.707a1 1 0 001.414 0L5 8zm4.707-3.293a1 1 0 00-1.414-1.414l1.414 1.414zm-7.414 2l2 2 1.414-1.414-2-2-1.414 1.414zm3.414 2l4-4-1.414-1.414-4 4 1.414 1.414z" />
          </svg>
        </span>
      </span>
    </button>
    """
  end

  defp submit_input(assigns) do
    ~H"""
    <div class="flex items-center justify-end mt-4 space-x-2">
      <%= if @locked do %>
        <svg class="w-5 h-5 text-gray-600 dark:text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path></svg>
      <% end %>

      <button
        class={"block px-3 py-2 font-medium text-sm text-gray-600 dark:text-gray-100 bg-gray-300 dark:bg-blue-300 dark:bg-opacity-25 hover:bg-blue-500 hover:text-white dark:hover:bg-blue-500 dark:hover:text-white rounded-md shadow-sm #{if @disabled, do: "opacity-30 pointer-events-none"}"}
        disabled={@disabled}
        type="submit">
        <%= @label %>
      </button>
    </div>
    """
  end

  defp pro_blocker(assigns) do
    ~H"""
    <span rel="requires-pro" class="text-center w-full text-sm text-gray-600 dark:text-gray-300 absolute top-1/2 -mt-6 -ml-3">
      Requires <a href="https://getoban.pro" class="text-blue-500 font-semibold">Oban Pro <svg class="w-3 h-3 inline-block align-text-top" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"></path></svg></a>
    </span>
    """
  end

  # Helpers

  defp local_limit([]), do: 0

  defp local_limit(gossip) do
    gossip
    |> Enum.map(& &1["local_limit"])
    |> Enum.max()
  end

  defp global_limit(gossip) do
    gossip
    |> Enum.map(& &1["global_limit"])
    |> Enum.filter(&is_map/1)
    |> List.first()
    |> case do
      %{"allowed" => allowed} -> allowed
      _ -> nil
    end
  end

  defp rate_limit_allowed(gossip) do
    gossip
    |> Enum.map(& &1["rate_limit"])
    |> Enum.filter(&is_map/1)
    |> Enum.find_value(& &1["allowed"])
  end

  defp rate_limit_period(gossip) do
    gossip
    |> Enum.map(& &1["rate_limit"])
    |> Enum.filter(&is_map/1)
    |> Enum.find_value(& &1["period"])
  end

  defp rate_limit_partition_fields(gossip) do
    case first_rate_limit(gossip) do
      %{"partition" => %{"fields" => [_ | _] = fields}} -> Enum.join(fields, ",")
      _ -> nil
    end
  end

  defp rate_limit_partition_keys(gossip) do
    case first_rate_limit(gossip) do
      %{"partition" => %{"keys" => [_ | _] = keys}} -> Enum.join(keys, ",")
      _ -> nil
    end
  end

  defp rate_limit_unchanged?(gossip, inputs) do
    inputs.rate_limit_allowed == rate_limit_allowed(gossip) and
      inputs.rate_limit_period == rate_limit_period(gossip) and
      inputs.rate_limit_partition_fields == rate_limit_partition_fields(gossip) and
      inputs.rate_limit_partition_keys == rate_limit_partition_keys(gossip)
  end

  defp first_rate_limit(gossip) do
    gossip
    |> Enum.map(& &1["rate_limit"])
    |> Enum.filter(&is_map/1)
    |> List.first()
  end

  defp change_input(socket, field, change) do
    field = String.to_existing_atom(field)

    inputs =
      Map.update!(socket.assigns.inputs, field, fn value ->
        if is_integer(value) and value + change > 0 do
          value + change
        else
          value
        end
      end)

    assign(socket, inputs: inputs)
  end

  defp maybe_split(""), do: []
  defp maybe_split(nil), do: []
  defp maybe_split(value) when is_binary(value), do: String.split(value, ",")

  # Pro Helpers

  defp missing_pro?(%Config{engine: engine}) do
    engine in [Oban.Queue.BasicEngine, Oban.Engines.Basic]
  end
end
