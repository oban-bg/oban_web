defmodule Oban.Web.NewJobPage do
  @behaviour Oban.Web.Page

  use Oban.Web, :live_component

  alias Oban.Web.NewJob.FormComponent
  alias Oban.Web.Page

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="new-job-page" class="flex-1 w-full flex flex-col my-6">
      <div class="max-w-2xl mx-auto w-full">
        <div class="bg-white dark:bg-gray-900 rounded-md shadow-lg">
          <div class="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
            <h2 class="text-lg font-semibold dark:text-gray-200">Enqueue Job</h2>
          </div>

          <.live_component
            id="new-job-form"
            module={FormComponent}
            access={@access}
            conf={@conf}
            resolver={@resolver}
            user={@user}
          />
        </div>
      </div>
    </div>
    """
  end

  @impl Page
  def handle_mount(socket) do
    assign(socket, page_title: page_title("Enqueue Job"))
  end

  @impl Page
  def handle_refresh(socket), do: socket

  @impl Page
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl Page
  def handle_info(_message, socket), do: {:noreply, socket}
end
