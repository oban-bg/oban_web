defmodule Oban.Web.InstancesComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Resolver

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    instances = available_instances(assigns.resolver, assigns.user)
    active = inspect(assigns.conf.name)

    socket =
      socket
      |> assign(conf: assigns.conf, id: assigns.id)
      |> assign(resolver: assigns.resolver, user: assigns.user)
      |> assign(active: active, instances: instances)

    {:ok, socket}
  end

  defp available_instances(resolver, user) do
    instances = oban_instances()

    available =
      case Resolver.call_with_fallback(resolver, :resolve_instances, [user]) do
        :all -> instances
        list -> Enum.filter(instances, &(&1 in list))
      end

    available
    |> Enum.map(&inspect/1)
    |> Enum.sort()
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div class="relative" id="instance-select" phx-hook="Instantiator">
      <button
        aria-expanded="true"
        aria-haspopup="listbox"
        class="rounded-md px-3 py-2 text-sm text-gray-600 dark:text-gray-300
        hover:text-gray-800 dark:hover:text-gray-200
        hover:bg-black/5 dark:hover:bg-white/5
        ring-1 ring-inset ring-gray-400 dark:ring-gray-700
        focus:outline-none focus:ring-blue-500 dark:focus:ring-blue-500"
        data-title="Change Oban instance"
        id="instance-select-button"
        phx-click={JS.toggle(to: "#instance-select-menu")}
        phx-hook="Tippy"
        type="button"
      >
        {@active}
      </button>

      <ul
        class="hidden absolute z-10 top-full right-0 mt-2 text-sm font-semibold overflow-auto rounded-md bg-white dark:bg-gray-800 shadow-lg ring-1 ring-black ring-opacity-5"
        id="instance-select-menu"
      >
        <li
          :for={name <- @instances}
          class="block w-full flex items-center space-x-2 py-1 px-2 cursor-pointer select-none hover:bg-gray-50 hover:dark:bg-gray-600/30"
          role="option"
          phx-click="select-instance"
          phx-click-away={JS.hide(to: "#instance-select-menu")}
          phx-target={@myself}
          phx-value-name={name}
        >
          <%= if name == @active do %>
            <Icons.check class="w-4 h-4 text-blue-500" />
          <% else %>
            <span class="block w-4 h-4"></span>
          <% end %>
          <span class="text-gray-800 dark:text-gray-200">
            {name}
          </span>
        </li>
      </ul>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("select-instance", %{"name" => name}, socket) do
    %{resolver: resolver, user: user} = socket.assigns

    allowed = Resolver.call_with_fallback(resolver, :resolve_instances, [user])

    if allowed == :all or Enum.member?(allowed, name) do
      send(self(), {:select_instance, name})
    end

    {:noreply, socket}
  end
end
