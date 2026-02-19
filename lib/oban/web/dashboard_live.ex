defmodule Oban.Web.DashboardLive do
  use Oban.Web, :live_view

  alias Oban.Web.{CronsPage, JobsPage, QueuesPage}

  @impl Phoenix.LiveView
  def mount(params, session, socket) do
    %{"prefix" => prefix, "resolver" => resolver} = session
    %{"live_path" => live_path, "live_transport" => live_transport} = session
    %{"user" => user, "access" => access, "csp_nonces" => csp_nonces} = session
    %{"refresh" => refresh, "logo_path" => logo_path} = session

    refresh = restore_state(socket, "refresh", refresh)
    theme = restore_state(socket, "theme", "system")
    sidebar_width = restore_state(socket, "sidebar_width", 320)
    oban = current_oban_instance(session, socket)

    conf = await_init([oban])
    _met = await_init([oban, Oban.Met])
    page = resolve_page(params)

    Process.put(:routing, {socket, prefix})

    socket =
      socket
      |> assign(conf: conf, params: params, page: page, init_state: init_state(socket))
      |> assign(live_path: live_path, live_transport: live_transport, logo_path: logo_path)
      |> assign(access: access, csp_nonces: csp_nonces, resolver: resolver, user: user)
      |> assign(original_refresh: nil, refresh: refresh, timer: nil, theme: theme)
      |> assign(sidebar_width: sidebar_width)
      |> init_schedule_refresh()
      |> page.comp.handle_mount()

    {:ok, socket}
  end

  defp current_oban_instance(session, socket) do
    stashed = restore_state(socket, "instance")
    default = List.first(oban_instances())

    case stashed || session["oban"] || default || Oban do
      name when is_binary(name) -> name |> String.split(".") |> Module.safe_concat()
      name -> name
    end
  end

  defp init_state(socket) do
    case get_connect_params(socket) do
      %{"init_state" => state} -> state
      _ -> %{}
    end
  end

  defp restore_state(socket, key, default \\ nil) do
    socket
    |> init_state()
    |> Map.get("oban:" <> key, default)
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:id, "page")
      |> Map.drop(~w(flash live_path live_transport refresh socket timer)a)

    ~H"""
    <.live_component id="page" module={@page.comp} {assigns} />
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
    page = resolve_page(params)

    if page == socket.assigns.page do
      page.comp.handle_params(params, uri, socket)
    else
      socket =
        socket
        |> assign(params: params, page: page)
        |> page.comp.handle_mount()

      page.comp.handle_params(params, uri, socket)
    end
  end

  @impl Phoenix.LiveView
  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  def handle_info(:pause_refresh, socket) do
    socket =
      if socket.assigns.refresh > 0 do
        cancel_timer(socket)

        assign(socket, refresh: -1, original_refresh: socket.assigns.refresh, timer: nil)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info(:resume_refresh, socket) do
    if original = socket.assigns.original_refresh do
      handle_info({:update_refresh, original}, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_info({:select_instance, name}, socket) do
    name = name |> String.split(".") |> Module.safe_concat()
    conf = Oban.config(name)
    name = inspect(name)
    page = socket.assigns.page

    socket =
      socket
      |> assign(oban: name, conf: conf)
      |> push_event("select-instance", %{name: name})
      |> put_flash_with_clear(:info, "Switched instance to #{name}")
      |> page.comp.handle_refresh()

    {:noreply, socket}
  end

  def handle_info(:toggle_refresh, socket) do
    %{original_refresh: original, refresh: refresh} = socket.assigns

    cond do
      refresh > 0 ->
        socket =
          socket
          |> assign(refresh: -1, original_refresh: refresh)
          |> push_event("update-refresh", %{refresh: -1})

        {:noreply, socket}

      is_integer(original) ->
        handle_info({:update_refresh, original}, socket)

      true ->
        handle_info({:update_refresh, 1}, socket)
    end
  end

  def handle_info({:update_refresh, refresh}, socket) do
    socket =
      socket
      |> assign(refresh: refresh, original_refresh: nil)
      |> schedule_refresh()

    {:noreply, push_event(socket, "update-refresh", %{refresh: refresh})}
  end

  def handle_info({:update_theme, theme}, socket) do
    {:noreply,
     socket
     |> assign(theme: theme)
     |> push_event("update-theme", %{theme: theme})}
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

  @impl Phoenix.LiveView
  def handle_event("sidebar_resize", %{"width" => width}, socket) do
    {:noreply, assign(socket, sidebar_width: width)}
  end

  def handle_event(event, params, socket) do
    socket.assigns.page.comp.handle_event(event, params, socket)
  end

  ## Mount Helpers

  defp await_init(args, opts \\ [])

  defp await_init([oban_name | _] = args, opts) do
    retries = Keyword.get(opts, :retries, 150)
    timeout = Keyword.get(opts, :timeout, 100)

    case apply(Oban.Registry, :whereis, args) do
      nil when retries > 0 ->
        Process.sleep(timeout)

        await_init(args, Keyword.put(opts, :retries, retries - 1))

      nil ->
        raise RuntimeError, "no config registered for #{inspect(args)} instance"

      pid when is_pid(pid) ->
        Oban.config(oban_name)
    end
  end

  ## Render Helpers

  defp resolve_page(%{"page" => "jobs"}), do: %{name: :jobs, comp: JobsPage}
  defp resolve_page(%{"page" => "queues"}), do: %{name: :queues, comp: QueuesPage}
  defp resolve_page(%{"page" => "crons"}), do: %{name: :crons, comp: CronsPage}
  defp resolve_page(_params), do: %{name: :jobs, comp: JobsPage}

  ## Refresh Helpers

  defp init_schedule_refresh(socket) do
    if connected?(socket) do
      schedule_refresh(socket)
    else
      assign(socket, timer: nil)
    end
  end

  defp schedule_refresh(socket) do
    cancel_timer(socket)

    if socket.assigns.refresh > 0 do
      interval = :timer.seconds(socket.assigns.refresh) - 50

      assign(socket, timer: Process.send_after(self(), :refresh, interval))
    else
      assign(socket, timer: nil)
    end
  end

  defp cancel_timer(socket) do
    if is_reference(socket.assigns.timer), do: Process.cancel_timer(socket.assigns.timer)
  end
end
