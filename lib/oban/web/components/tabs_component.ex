defmodule Oban.Web.TabsComponent do
  use Oban.Web, :live_component

  def render(assigns) do
    ~L"""
    <nav class="ml-8 flex space-x-2">
      <a href="<%= oban_path(@socket, :jobs) %>" phx-link="patch" class="text-gray-300 hover:text-gray-100 <%= if @page == :jobs do %>bg-blue-300 bg-opacity-25 <% end %>px-3 py-2 font-medium text-sm rounded-md">Jobs</a>
      <a href="<%= oban_path(@socket, :queues) %>" phx-link="patch" class="text-gray-300 hover:text-gray-100 <%= if @page == :queues do %>bg-blue-300 bg-opacity-25 <% end %>px-3 py-2 font-medium text-sm rounded-md">Queues</a>
    </nav>
    """
  end
end
