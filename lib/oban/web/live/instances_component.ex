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
    <div id="instance-select" phx-hook="Instantiator">
      <div
        :if={length(@instances) < 2}
        class="flex h-9 px-3 items-center text-sm text-gray-600 dark:text-gray-300"
      >
        <span class="sr-only">Current Oban instance</span>
        <span class="truncate max-w-40">{@active}</span>
      </div>

      <Core.dropdown_menu
        :if={length(@instances) >= 2}
        id="instance-select"
        title="Change Oban instance"
        menu_class="max-h-64 max-w-96 overflow-auto"
        toggle_class="flex h-9 px-3 items-center gap-1.5 text-sm text-gray-600 dark:text-gray-300
        hover:text-gray-800 dark:hover:text-gray-200
        hover:bg-black/5 dark:hover:bg-white/5
        ring-1 ring-inset ring-gray-400 dark:ring-gray-700"
      >
        <:toggle>
          <span class="sr-only">Change Oban instance, currently</span>
          <span class="truncate max-w-40">{@active}</span>
          <Icons.icon
            name="icon-chevron-down"
            class="w-4 h-4 shrink-0 text-gray-400 dark:text-gray-500"
          />
        </:toggle>

        <.option :for={name <- @instances} active={@active} myself={@myself} name={name} />
      </Core.dropdown_menu>
    </div>
    """
  end

  attr :active, :string, required: true
  attr :myself, :any, required: true
  attr :name, :string, required: true

  defp option(assigns) do
    ~H"""
    <Core.menu_option
      class="select-none"
      selected={@name == @active}
      phx-click={
        "select-instance"
        |> JS.push(target: @myself)
        |> Core.close_menu("instance-select")
        |> JS.focus(to: "#instance-select-menu-toggle")
      }
      phx-value-name={@name}
    >
      <%= if @name == @active do %>
        <Icons.icon name="icon-check" class="w-5 h-5 shrink-0 text-blue-500" />
      <% else %>
        <span class="block w-5 h-5 shrink-0"></span>
      <% end %>
      <span class={[
        "truncate",
        if(@name == @active,
          do: "text-blue-500 dark:text-blue-400",
          else: "text-gray-800 dark:text-gray-200"
        )
      ]}>
        {@name}
      </span>
    </Core.menu_option>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("select-instance", %{"name" => name}, socket) do
    %{resolver: resolver, user: user} = socket.assigns

    allowed = Resolver.call_with_fallback(resolver, :resolve_instances, [user])

    if allowed == :all or name in Enum.map(allowed, &inspect/1) do
      send(self(), {:select_instance, name})
    end

    {:noreply, socket}
  end
end
