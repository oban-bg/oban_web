defmodule Oban.Web.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Web.DetailView

  def render(assigns) do
    DetailView.render("show.html", assigns)
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

  def handle_event("delete", _params, socket) do
    send(self(), {:delete_job, socket.assigns.job.id})

    {:noreply, socket}
  end

  def handle_event("deschedule", _params, socket) do
    send(self(), {:deschedule_job, socket.assigns.job.id})

    {:noreply, socket}
  end

  def handle_event("discard", _params, socket) do
    send(self(), {:discard_job, socket.assigns.job.id})

    {:noreply, socket}
  end

  def handle_event("kill", _params, socket) do
    send(self(), {:kill_job, socket.assigns.job.id})

    {:noreply, socket}
  end
end
