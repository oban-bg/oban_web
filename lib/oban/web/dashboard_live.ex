defmodule Oban.Web.DashboardLive do
  use Oban.Web, :live_view

  alias Oban.Web.Plugins.Stats
  alias Oban.Web.{LayoutComponent, RefreshComponent}
  alias Oban.Web.{JobsPage, QueuesPage}

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    %{"oban" => oban, "refresh" => refresh} = session
    %{"socket_path" => path, "transport" => transport} = session
    %{"user" => user, "access" => access, "csp_nonces" => csp_nonces} = session

    conf = await_config(oban)
    page = resolve_page(params)

    :ok = Stats.activate(oban)

    socket =
      socket
      |> assign(conf: conf, params: params, page: page)
      |> assign(csp_nonces: csp_nonces, live_path: path, live_transport: transport)
      |> assign(access: access, user: user)
      |> assign(refresh: refresh, timer: nil)
      |> init_schedule_refresh()
      |> page.comp.handle_mount()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <meta name="live-transport" content={@live_transport} />
    <meta name="live-path" content={@live_path} />

    <main class="p-4 min-h-screen flex flex-col">
      <LayoutComponent.notify flash={@flash} />

      <header class="flex items-center">
        <LayoutComponent.logo />
        <LayoutComponent.tabs socket={@socket} page={@page.name} />

        <.live_component module={RefreshComponent} id="refresh" refresh={@refresh} />
      </header>

      <%= render_page(@page, assigns) %>

      <LayoutComponent.footer />
    </main>
    """
  end

  @impl Phoenix.LiveView
  def terminate(_reason, %{assigns: %{timer: timer}}) do
    if is_reference(timer), do: Process.cancel_timer(timer)

    :ok
  end

  def terminate(_reason, _socket), do: :ok

  @impl Phoenix.LiveView
  def handle_params(params, uri, socket) do
    socket.assigns.page.comp.handle_params(params, uri, socket)
  end

  @impl Phoenix.LiveView
  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info({:update_refresh, refresh}, socket) do
    socket =
      socket
      |> assign(refresh: refresh)
      |> schedule_refresh()

    {:noreply, socket}
  end

  def handle_info(:refresh, socket) do
    socket =
      socket
      |> socket.assigns.page.comp.handle_refresh()
      |> schedule_refresh()

    {:noreply, socket}
  end

  def handle_info(message, socket) do
    socket.assigns.page.comp.handle_info(message, socket)
  end

  ## Mount Helpers

  defp await_config(oban_name, timeout \\ 15_000) do
    Oban.config(oban_name)
  rescue
    exception in [RuntimeError] ->
      handler = fn _event, _timing, %{conf: conf}, pid ->
        send(pid, {:conf, conf})
      end

      :telemetry.attach("oban-await-config", [:oban, :supervisor, :init], handler, self())

      receive do
        {:conf, %{name: ^oban_name} = conf} ->
          conf
      after
        timeout -> reraise(exception, __STACKTRACE__)
      end
  after
    :telemetry.detach("oban-await-config")
  end

  ## Render Helpers

  defp resolve_page(%{"page" => "jobs"}), do: %{name: :jobs, comp: JobsPage}
  defp resolve_page(%{"page" => "queues"}), do: %{name: :queues, comp: QueuesPage}
  defp resolve_page(_params), do: %{name: :jobs, comp: JobsPage}

  defp render_page(page, assigns) do
    assigns =
      assigns
      |> Map.put(:id, "page")
      |> Map.drop([:csp_nonces, :live_path, :live_transport, :refresh, :timer])

    live_component(page.comp, assigns)
  end

  ## Refresh Helpers

  defp init_schedule_refresh(socket) do
    if connected?(socket) do
      schedule_refresh(socket)
    else
      assign(socket, timer: nil)
    end
  end

  defp schedule_refresh(socket) do
    if is_reference(socket.assigns.timer), do: Process.cancel_timer(socket.assigns.timer)

    if socket.assigns.refresh > 0 do
      interval = :timer.seconds(socket.assigns.refresh) - 50

      assign(socket, timer: Process.send_after(self(), :refresh, interval))
    else
      assign(socket, timer: nil)
    end
  end
end
