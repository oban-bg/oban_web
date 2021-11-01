defmodule Oban.Web.DarknessComponent do
  use Phoenix.Component

  def toggle(assigns) do
    ~H"""
    <button class="focus:outline-none transition duration-200 ease-out p-2 relative text-purple-500 bg-purple-500 bg-opacity-12.5 focus:bg-opacity-25 rounded-full">
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 20 20" xmlns="http://www.w3.org/2000/svg"><path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z"></path></svg>
    </button>
    """
  end
end
