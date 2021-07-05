defmodule Oban.Web.Jobs.QueueComponent do
  use Oban.Web, :live_component

  @local_timeout 10
  @limit_min 1
  @limit_max 100

  def mount(socket) do
    {:ok, assign(socket, expanded?: false, update_at: nil)}
  end

  def update(assigns, socket) do
    socket =
      assign(
        socket,
        access: assigns.access,
        active?: assigns.name == assigns.params[:queue],
        avail: assigns.stat.avail,
        controls?: can?(:scale_queues, assigns.access) or can?(:pause_queues, assigns.access),
        execu: assigns.stat.execu,
        name: assigns.name
      )

    socket =
      if recent_local_update?(socket.assigns) do
        socket
      else
        assign(
          socket,
          limit: assigns.stat.limit,
          local: assigns.stat.local,
          paused?: assigns.stat.pause,
          ratio: safe_div(assigns.stat.limit, assigns.stat.local),
          update_at: nil
        )
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~L"""
    <li class="text-sm">
      <div id="queue-<%= @name %>" tabindex="0" phx-click="filter" phx-target="<%= @myself %>" class="group flex outline-none cursor-pointer justify-between py-3 border-l-4 border-transparent hover:bg-gray-50 dark:hover:bg-gray-800 <%= if @expanded? do %>bg-gray-50 dark:bg-gray-800<% end %> <%= if @active? do %>border-blue-400<% end %>">
        <span class="pl-2 flex-initial font-semibold truncate dark:text-gray-300 <%= if @paused? do %>text-gray-400 dark:text-gray-600 line-through<% end %>" title="<%= if @paused? do %>Paused<% end %>"><%= @name %></span>

        <div class="pr-3 flex-none <%= if @controls? do %>group-hover:hidden<% end %>">
          <span class="text-gray-500 inline-block text-right w-10 tabular"><%= integer_to_estimate(@execu) %></span>
          <span class="text-gray-500 inline-block text-right w-10 tabular"><%= integer_to_estimate(@limit) %></span>
          <span class="text-gray-500 inline-block text-right w-10 tabular"><%= integer_to_estimate(@avail) %></span>
        </div>

        <div class="pr-3 hidden <%= if @controls? do %>group-hover:flex<% end %>">
          <%= if can?(:scale_queues, @access) do %>
            <button class="block w-5 h-5 text-gray-400 hover:text-blue-500" title="Expand queue scaling" phx-click="expand" phx-target="<%= @myself %>">
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M5 4a1 1 0 00-2 0v7.268a2 2 0 000 3.464V16a1 1 0 102 0v-1.268a2 2 0 000-3.464V4zM11 4a1 1 0 10-2 0v1.268a2 2 0 000 3.464V16a1 1 0 102 0V8.732a2 2 0 000-3.464V4zM16 3a1 1 0 011 1v7.268a2 2 0 010 3.464V16a1 1 0 11-2 0v-1.268a2 2 0 010-3.464V4a1 1 0 011-1z"></path></svg>
            </button>
          <% end %>

          <%= if can?(:pause_queues, @access) do %>
            <button class="ml-3 block w-5 h-5 text-gray-400 hover:text-blue-500" title="Pause or resume queue" phx-click="play_pause" phx-target="<%= @myself %>" phx-throttle="500">
              <%= if @paused? do %>
                <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
              <% else %>
                <svg fill="currentColor" viewBox="0 0 20 20"><path d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
              <% end %>
            </button>
          <% end %>
        </div>
      </div>

      <%= if can?(:scale_queues, @access) do %>
        <div class="w-full px-3 bg-white dark:bg-gray-900 shadow-inner overflow-hidden transition-all duration-300 ease-in-out <%= if @expanded? do %>h-16 py-2 bg-gray-100 dark:bg-gray-700<% else %>h-0<% end %>">
          <form phx-submit="scale" phx-target="<%= @myself %>">
            <div class="flex justify-between items-center mt-2 w-full">
              <label for="queue-<%= @name %>-limit" class="block w-full text-xs font-bold text-gray-600 dark:text-gray-300">Per Node Limit</label>
              <input phx-update="ignore" id="queue-<%= @name %>-limit" type="number" name="local" min="1" max="100" step="1" value="<%= @local %>" class="tabular bg-white dark:bg-gray-800 rounded px-2 py-2 w-20 text-gray-700 dark:text-gray-300">
              <button class="bg-gray-200 dark:bg-gray-700 rounded ml-3 px-2 py-2 text-gray-700 dark:text-gray-300 hover:bg-blue-500 hover:text-white">Scale</button>
            </div>
          </form>
        </div>
      <% end %>
    </li>
    """
  end

  def safe_div(_, 0), do: 0
  def safe_div(num, dem), do: div(num, dem)

  def handle_event("filter", _params, socket) do
    new_queue = if socket.assigns.active?, do: nil, else: socket.assigns.name

    send(self(), {:params, :queue, new_queue})

    {:noreply, socket}
  end

  def handle_event("expand", _params, socket) do
    {:noreply, assign(socket, expanded?: not socket.assigns.expanded?)}
  end

  def handle_event("scale", %{"local" => local}, socket) do
    if can?(:scale_queues, socket.assigns.access) do
      local =
        local
        |> String.to_integer()
        |> min(@limit_max)
        |> max(@limit_min)

      limit = local * socket.assigns.ratio

      send(self(), {:scale_queue, socket.assigns.name, local})

      {:noreply, assign(socket, local: local, limit: limit, update_at: DateTime.utc_now())}
    else
      {:noreply, socket}
    end
  end

  def handle_event("play_pause", _params, socket) do
    if can?(:pause_queues, socket.assigns.access) do
      action = if socket.assigns.paused?, do: :resume_queue, else: :pause_queue

      send(self(), {action, socket.assigns.name})

      {:noreply,
       assign(socket, paused?: not socket.assigns.paused?, update_at: DateTime.utc_now())}
    else
      {:noreply, socket}
    end
  end

  defp recent_local_update?(%{update_at: update_at}) do
    expires_at = DateTime.add(DateTime.utc_now(), -@local_timeout)

    not is_nil(update_at) and DateTime.compare(update_at, expires_at) == :gt
  end
end
