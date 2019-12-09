defmodule ObanWeb.DetailComponent do
  @moduledoc false

  use Phoenix.LiveComponent

  alias ObanWeb.DashboardView

  def render(assigns) do
    DashboardView.render("detail.html", assigns)
  end

  def handle_event("close", %{"code" => "Escape"}, socket) do
    send(self(), :close_modal)

    {:noreply, socket}
  end

  def handle_event("close", %{"action" => "close"}, socket) do
    send(self(), :close_modal)

    {:noreply, socket}
  end

  def handle_event("close", _params, socket) do
    {:noreply, socket}
  end
end
