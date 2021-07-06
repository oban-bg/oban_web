defmodule Oban.Web.FooterComponent do
  use Oban.Web, :live_component

  def render(assigns) do
    ~L"""
    <footer class="flex flex-col px-3 pb-6 text-sm justify-center items-center md:flex-row">
      <span class="text-gray-600 dark:text-gray-400 tabular mr-0 mb-1 md:mr-3 md:mb-0">Oban v<%= Application.spec(:oban, :vsn) %></span>
      <span class="text-gray-600 dark:text-gray-400 tabular mr-0 mb-1 md:mr-3 md:mb-0">Oban.Web v<%= Application.spec(:oban_web, :vsn) %></span>
      <span class="text-gray-600 dark:text-gray-400 tabular mr-0 mb-3 md:mr-3 md:mb-0">Oban.Pro v<%= Application.spec(:oban_pro, :vsn) %></span>

      <span class="text-gray-800 dark:text-gray-200 mr-1">
        <svg fill="currentColor" viewBox="0 0 20 20" class="h-5 w-5"><path fill-rule="evenodd" d="M18 3.315a.251.251 0 00-.073-.177l-1.065-1.065a.25.25 0 00-.353 0l-1.772 1.773a7.766 7.766 0 00-10.89 10.89L2.072 16.51a.251.251 0 000 .352l1.066 1.066a.25.25 0 00.352 0l1.773-1.772a7.766 7.766 0 0010.89-10.891l1.773-1.773A.252.252 0 0018 3.315zM5.474 10c0-1.21.471-2.345 1.326-3.2A4.496 4.496 0 0110 5.474c.867 0 1.697.243 2.413.695l-6.244 6.244A4.495 4.495 0 015.474 10zm9.052 0c0 1.209-.471 2.345-1.326 3.2a4.496 4.496 0 01-3.2 1.326 4.497 4.497 0 01-2.413-.695l6.244-6.244c.452.716.695 1.546.695 2.413z" /></svg>
      </span>

      <span class="text-gray-800 dark:text-gray-200 font-semibold">Made by Soren</span>
    </footer>
    """
  end
end
