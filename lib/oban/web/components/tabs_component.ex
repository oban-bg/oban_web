defmodule Oban.Web.TabsComponent do
  use Oban.Web, :live_component

  @base "text-gray-300 hover:text-gray-100 px-3 py-2 font-medium text-sm rounded-md"

  def render(assigns) do
    ~L"""
    <nav class="ml-8 flex space-x-2">
      <%= live_redirect "Jobs", to: oban_path(@socket, :jobs), class: link_class(@page, :jobs) %>
      <%= live_redirect "Queues", to: oban_path(@socket, :queues), class: link_class(@page, :queues) %>
    </nav>
    """
  end

  defp link_class(page, page), do: @base <> " bg-blue-300 bg-opacity-25"
  defp link_class(_pag, _exp), do: @base
end
