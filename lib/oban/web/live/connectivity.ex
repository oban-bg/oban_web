defmodule Oban.Web.Live.Connectivity do
  use Oban.Web, :live_component

  @con_interval 60_000
  @dis_interval 15_000

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(conf: assigns.conf, id: assigns.id)
      |> assign(:pubsub?, Map.get(assigns, :pubsub?, true))

    if connected?(socket) do
      interval = if socket.assigns.pubsub?, do: @con_interval, else: @dis_interval

      check_after(socket, interval)
    end

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="connectivity" data-title="Pubsub disconnected, updates degraded" phx-hook="Tippy">
      <Icons.lightning_slash :if={not @pubsub?} class="w-6 h-6 animate-pulse text-red-500" />
    </div>
    """
  end

  defp check_after(socket, interval) do
    self = self()

    Task.async(fn ->
      Process.sleep(interval)

      assigns = Map.take(socket.assigns, ~w(id conf pubsub?)a)

      try do
        :ok = Oban.Notifier.listen(assigns.conf.name, :diagnostics)
        :ok = Oban.Notifier.notify(assigns.conf.name, :diagnostics, %{ping: :pong})

        receive do
          {:notification, :diagnostics, %{"ping" => "pong"}} ->
            send_update(self, __MODULE__, %{assigns | pubsub?: true})
        after
          1_000 ->
            send_update(self, __MODULE__, %{assigns | pubsub?: false})
        end
      catch
        :exit, _reason ->
          send_update(self, __MODULE__, %{assigns | pubsub?: false})
      end
    end)
  end
end
