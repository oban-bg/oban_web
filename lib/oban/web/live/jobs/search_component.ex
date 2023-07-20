defmodule Oban.Web.Jobs.SearchComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Search

  # TODO: Switch this to use a hook with event pushing to handle tab and focus

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, buffer: "")}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <form
      class="grow relative"
      id="search"
      data-shortcut={JS.focus(to: "#search-input")}
      phx-change="change"
      phx-submit="search"
      phx-target={@myself}
    >
      <div class="w-full flex items-center space-x-1.5 rounded-md shadow-inner ring-1 ring-inset ring-gray-300 ">
        <Icons.magnifying_glass class="ml-1.5 flex-none w-5 h-5 text-gray-500" />

        <div class="w-full flex flex-wrap space-x-1.5">
          <.filter :for={{param, terms} <- filterable(@params)} param={param} terms={terms} />

          <input
            aria-label="Add filters"
            aria-placeholder="Add filters"
            autocorrect="false"
            class="min-w-[10rem] flex-grow my-2 p-0 text-sm appearance-none border-none bg-transparent placeholder-gray-400 dark:placeholder-gray-600 focus:ring-0"
            id="search-input"
            onblur="this.parentNode.parentNode.classList.remove('shadow-blue-100', 'ring-blue-500', 'bg-blue-100/30')"
            onfocus="this.parentNode.parentNode.classList.add('shadow-blue-100', 'ring-blue-500', 'bg-blue-100/30')"
            name="terms"
            phx-debounce="100"
            phx-focus={JS.show(to: "#search-suggest") |> JS.push_focus()}
            phx-key="tab"
            phx-keydown="complete"
            phx-target={@myself}
            placeholder="Add filters"
            spellcheck="false"
            type="search"
            value={@buffer}
          />
        </div>
      </div>

      <button
        class={"absolute inset-y-0 right-0 pr-3 items-center text-gray-400 hover:text-blue-500 #{clear_class(@buffer)}"}
        data-title="Clear filters"
        id="search-reset"
        phx-hook="Tippy"
        phx-target={@myself}
        phx-click="clear"
        type="reset"
      >
        <Icons.x_circle class="w-5 h-5" />
      </button>

      <nav
        class="hidden absolute z-10 mt-1 p-2 w-full text-sm bg-white shadow-lg rounded-md ring-1 ring-black ring-opacity-5"
        id="search-suggest"
        phx-click-away={JS.hide()}
      >
        <.option
          :for={{name, desc, exmp} <- Search.suggest(@buffer, @conf)}
          name={name}
          desc={desc}
          exmp={exmp}
        />
      </nav>
    </form>
    """
  end

  attr :param, :any, required: true
  attr :terms, :any, required: true

  defp filter(assigns) do
    ~H"""
    <div class="my-1.5 flex items-center text-sm font-medium" id={"search-filter-#{@param}"}>
      <span class="pl-1.5 pr-0.5 py-1 text-gray-700 bg-violet-100 rounded-s-md whitespace-nowrap">
        <%= @param %>:<%= @terms |> List.wrap() |> Enum.join(",") %>
      </span>
      <button
        class="pl-0.5 pr-1 py-1 rounded-e-md text-gray-800/70 bg-violet-100 hover:bg-violet-300 hover:text-gray-800"
        type="button"
        phx-click="remove-filter"
        phx-value-param={@param}
        phx-value-terms={@terms}
        phx-target="#search"
      >
        <Icons.x_mark class="w-5 h-5" />
      </button>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :desc, :string
  attr :exmp, :string

  defp option(assigns) do
    ~H"""
    <button
      class="block w-full flex items-center cursor-pointer p-1 rounded-md group hover:bg-blue-600"
      phx-click={JS.push("append", value: %{choice: @name})}
      phx-target="#search"
      type="button"
    >
      <span class="block px-1 py-0.5 font-medium rounded-sm bg-gray-100"><%= @name %></span>
      <span class="block ml-2 text-gray-600 group-hover:text-white"><%= @desc %></span>
      <span class="block ml-auto text-right text-gray-400 group-hover:text-white"><%= @exmp %></span>
    </button>
    """
  end

  defp filterable(params), do: Map.take(params, ~w(nodes queues workers)a)

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("change", %{"terms" => terms}, socket) do
    {:noreply, assign(socket, buffer: terms)}
  end

  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(buffer: "")
     |> push_patch(to: oban_path(:jobs))}
  end

  def handle_event("append", %{"choice" => choice}, socket) do
    socket.assigns.buffer
    |> Search.append(choice)
    |> handle_submit(socket)
  end

  def handle_event("complete", %{"key" => "Tab"}, socket) do
    socket.assigns.buffer
    |> Search.complete(socket.assigns.conf)
    |> handle_submit(socket)
  end

  def handle_event("search", _, socket) do
    handle_submit(socket.assigns.buffer, socket)
  end

  def handle_event("remove-filter", %{"param" => param, "terms" => _}, socket) do
    params = Map.delete(socket.assigns.params, String.to_existing_atom(param))

    {:noreply, push_patch(socket, to: oban_path(:jobs, params))}
  end

  defp handle_submit(buffer, socket) do
    if String.ends_with?(buffer, ":") do
      {:noreply, assign(socket, buffer: buffer)}
    else
      parsed = Search.parse(buffer)
      params = Map.merge(socket.assigns.params, parsed)

      {:noreply,
       socket
       |> assign(buffer: "")
       |> push_patch(to: oban_path(:jobs, params))}
    end
  end

  # Class Helpers

  defp clear_class(""), do: "hidden"
  defp clear_class(_terms), do: "block"
end
