defmodule Oban.Web.QueuesComponent do
  use Oban.Web, :live_component

  def render(assigns) do
    ~L"""
    <div id="queues-page" class="w-full flex bg-white dark:bg-gray-900 my-6 rounded-md shadow-lg overflow-hidden">
    </div>
    """
  end

  def handle_refresh(socket) do
    socket
  end

  def handle_params(_, _uri, socket) do
    {:noreply, socket}
  end

  def handle_info(_, socket) do
    {:noreply, socket}
  end
end
