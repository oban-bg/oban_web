defmodule Oban.Web.QueueComponent do
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
        name: assigns.name,
        active?: assigns.name == assigns.filters.queue,
        avail: assigns.stat.avail,
        execu: assigns.stat.execu
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
    <li id="queue-<%= @name %>" class="text-sm" phx-click="filter" phx-target="<%= @myself %>">
      <div class="group flex justify-between cursor-pointer py-3 border-l-2 border-transparent hover:bg-gray-50 <%= if @active? do %>border-blue-400<% end %>">
        <span class="pl-3 font-semibold <%= if @paused? do %>text-gray-400 line-through<% end %>" title="<%= if @paused? do %>Paused<% end %>"><%= @name %></span>

        <div class="pr-3 group-hover:hidden">
          <span class="text-gray-500 inline-block text-right w-12 tabular"><%= integer_to_delimited(@execu) %></span>
          <span class="text-gray-500 inline-block text-right w-12 tabular"><%= integer_to_delimited(@limit) %></span>
          <span class="text-gray-500 inline-block text-right w-12 tabular"><%= integer_to_delimited(@avail) %></span>
        </div>

        <div class="pr-3 hidden group-hover:flex">
          <button class="block w-5 h-5 text-gray-400 hover:text-blue-500" title="Expand queue scaling" phx-click="expand" phx-target="<%= @myself %>">
            <svg fill="currentColor" viewBox="0 0 20 20"><path d="M5 4a1 1 0 00-2 0v7.268a2 2 0 000 3.464V16a1 1 0 102 0v-1.268a2 2 0 000-3.464V4zM11 4a1 1 0 10-2 0v1.268a2 2 0 000 3.464V16a1 1 0 102 0V8.732a2 2 0 000-3.464V4zM16 3a1 1 0 011 1v7.268a2 2 0 010 3.464V16a1 1 0 11-2 0v-1.268a2 2 0 010-3.464V4a1 1 0 011-1z"></path></svg>
          </button>

          <button class="ml-3 block w-5 h-5 text-gray-400 hover:text-blue-500" title="Pause or resume queue" phx-click="play_pause" phx-target="<%= @myself %>" phx-throttle="500">
            <%= if @paused? do %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% else %>
              <svg fill="currentColor" viewBox="0 0 20 20"><path d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd" fill-rule="evenodd"></path></svg>
            <% end %>
          </button>
        </div>
      </div>

      <div class="w-full px-3 bg-white shadow-inner overflow-hidden transition-all duration-300 ease-in-out <%= if @expanded? do %>h-24 py-4 bg-gray-100<% else %>h-0<% end %>">
        <form phx-change="scale" phx-target="<%= @myself %>">
          <label for="limit" class="block w-full text-xs font-bold text-gray-600">Queue Limit (Per Node)</label>
          <div class="flex justify-between items-center mt-2 w-full">
            <input type="range" name="local" min="1" max="100" step="1" value="<%= @local %>" class="w-64 cursor-pointer" phx-debounce="100">
            <output for="local" class="tabular bg-white rounded px-2 py-2 w-10 text-center text-gray-700 select-none"><%= @local %></output>
          </div>
        </form>
      </div>
    </li>
    """
  end

  def safe_div(_, 0), do: 0
  def safe_div(num, dem), do: div(num, dem)

  def handle_event("filter", _params, socket) do
    new_queue = if socket.assigns.active?, do: "any", else: socket.assigns.name

    send(self(), {:filter_queue, new_queue})

    {:noreply, socket}
  end

  def handle_event("expand", _params, socket) do
    {:noreply, assign(socket, expanded?: not socket.assigns.expanded?)}
  end

  def handle_event("scale", %{"local" => local}, socket) do
    local =
      local
      |> String.to_integer()
      |> min(@limit_max)
      |> max(@limit_min)

    limit = local * socket.assigns.ratio

    send(self(), {:scale_queue, socket.assigns.name, local})

    {:noreply, assign(socket, local: local, limit: limit, update_at: DateTime.utc_now())}
  end

  def handle_event("play_pause", _params, socket) do
    action = if socket.assigns.paused?, do: :resume_queue, else: :pause_queue

    send(self(), {action, socket.assigns.name})

    {:noreply, assign(socket, paused?: not socket.assigns.paused?, update_at: DateTime.utc_now())}
  end

  defp recent_local_update?(%{update_at: update_at}) do
    expires_at = DateTime.add(DateTime.utc_now(), -@local_timeout)

    not is_nil(update_at) and DateTime.compare(update_at, expires_at) == :gt
  end
end
