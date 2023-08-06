defmodule Oban.Web.Jobs.SearchComponent do
  use Oban.Web, :live_component

  alias Oban.Web.Query

  @known ~w(args meta nodes priorities queues tags workers)a

  @spinner_timeout 100

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, buffer: "", loading: false)}
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    suggestions = Query.suggest(socket.assigns.buffer, assigns.conf, resolver: assigns.resolver)

    socket =
      socket
      |> assign(assigns)
      |> assign(suggestions: suggestions)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <form
      class="grow relative"
      id="search"
      data-shortcut={JS.focus(to: "#search-input")}
      phx-hook="Completer"
      phx-change="change"
      phx-submit="search"
      phx-target={@myself}
    >
      <div
        id="search-wrapper"
        class="w-full flex items-center space-x-1.5 rounded-md shadow-inner ring-1 ring-inset ring-gray-300"
      >
        <div class="ml-1.5 flex-none">
          <%= if @loading do %>
            <Icons.spinner class="w-5 h-5 text-gray-200 animate-spin dark:text-gray-600 fill-violet-500" />
          <% else %>
            <Icons.magnifying_glass class="w-5 h-5 text-gray-500" />
          <% end %>
        </div>

        <div class="w-full flex flex-wrap space-x-1.5">
          <.filter :for={{param, terms} <- filterable(@params)} param={param} terms={terms} />

          <input
            aria-label="Add filters"
            aria-placeholder="Add filters"
            autocorrect="false"
            class="min-w-[10rem] flex-grow my-2 px-0 py-0.5 text-sm appearance-none border-none bg-transparent placeholder-gray-400 dark:placeholder-gray-600 focus:ring-0"
            id="search-input"
            name="terms"
            phx-blur={hide_focus()}
            phx-debounce={100}
            phx-focus={show_focus()}
            phx-target={@myself}
            placeholder="Add filters"
            spellcheck="false"
            type="search"
            value={@buffer}
          />
        </div>
      </div>

      <button
        class={[
          "absolute inset-y-0 right-0 pr-3 items-center text-gray-400 hover:text-blue-500",
          unless(clearable?(@buffer, @params), do: "hidden")
        ]}
        data-title="Clear filters"
        id="search-reset"
        phx-target={@myself}
        phx-click="clear"
        type="reset"
      >
        <Icons.x_circle class="w-5 h-5" />
      </button>

      <nav
        class={[
          "hidden absolute z-10 mt-1 p-2 w-full text-sm bg-white shadow-lg",
          "rounded-md ring-1 ring-black ring-opacity-5"
        ]}
        id="search-suggest"
        phx-click-away={JS.hide()}
      >
        <.option
          :for={{name, desc, exmp} <- @suggestions}
          buff={@buffer}
          name={name}
          desc={desc}
          exmp={exmp}
        />

        <div :if={Enum.empty?(@suggestions)} class="w-full flex items-center space-x-2 p-1">
          <Icons.exclamation_circle class="w-5 h-5 text-gray-400" />
          <span class="text-gray-700">No suggestions matching <b>"<%= @buffer %>"</b></span>
        </div>
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
        <%= format_filter(@param, @terms) %>
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

  defp format_filter(param, [path, term]) when is_list(path) do
    "#{param}.#{Enum.join(path, ".")}:#{term}"
  end

  defp format_filter(param, term) when is_list(term) do
    "#{param}:#{Enum.join(term, ",")}"
  end

  defp format_filter(param, term) do
    "#{param}:#{term}"
  end

  attr :buff, :string
  attr :name, :string
  attr :desc, :string
  attr :exmp, :string

  defp option(assigns) do
    ~H"""
    <button
      class="block w-full flex items-center cursor-pointer p-1 rounded-md group hover:bg-violet-600"
      phx-click={JS.push("append", value: %{choice: @name})}
      phx-target="#search"
      type="button"
    >
      <span class="block px-1 py-0.5 font-medium rounded-sm bg-gray-100">
        <%= highlight(@name, @buff) %>
      </span>
      <span class="block ml-2 text-gray-600 group-hover:text-white"><%= @desc %></span>
      <span class="block ml-auto text-right text-gray-400 group-hover:text-white"><%= @exmp %></span>
    </button>
    """
  end

  defp clearable?(buffer, params) do
    String.length(buffer) > 0 or map_size(filterable(params)) > 0
  end

  defp filterable(params), do: Map.take(params, @known)

  defp highlight(value, substr) do
    match =
      substr
      |> String.split([":", "."], trim: true)
      |> List.last()

    if is_binary(value) and is_binary(match) do
      pattern = Regex.compile!("(#{match})", "i")

      value
      |> String.replace(pattern, "<b>\\1</b>")
      |> raw()
    else
      value
    end
  end

  def show_focus do
    "ring-gray-300"
    |> JS.remove_class(to: "#search-wrapper")
    |> JS.add_class("shadow-blue-100 ring-blue-500 bg-blue-100/30", to: "#search-wrapper")
    |> JS.show(to: "#search-suggest")
  end

  # Closing the suggest menu is done with push events to allow clicking on a suggestion to fire
  # before the menu closes.
  def hide_focus do
    "shadow-blue-100 ring-blue-500 bg-blue-100/30"
    |> JS.remove_class(to: "#search-wrapper")
    |> JS.add_class("ring-gray-300", to: "#search-wrapper")
  end

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("change", %{"terms" => buffer}, socket) do
    socket =
      socket
      |> assign(buffer: buffer)
      |> async_suggest(buffer)

    {:noreply, socket}
  end

  def handle_event("clear", _params, socket) do
    suggestions = Query.suggest("", socket.assigns.conf)

    {:noreply,
     socket
     |> assign(buffer: "", loading: false, suggestions: suggestions)
     |> push_patch(to: oban_path(:jobs))}
  end

  def handle_event("append", %{"choice" => choice}, socket) do
    buffer = Query.append(socket.assigns.buffer, choice)

    socket =
      socket
      |> assign(buffer: buffer)
      |> async_suggest(buffer)

    {:noreply, socket}
  end

  def handle_event("complete", _params, socket) do
    buffer = Query.complete(socket.assigns.buffer, socket.assigns.conf)

    socket =
      socket
      |> assign(buffer: buffer)
      |> push_event("completed", %{buffer: buffer})
      |> async_suggest(buffer)

    {:noreply, socket}
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
      socket =
        socket
        |> assign(buffer: buffer)
        |> async_suggest(buffer)

      {:noreply, socket}
    else
      parsed = Query.parse(buffer)
      params = Map.merge(socket.assigns.params, parsed, fn _key, old, new -> old ++ new end)
      suggestions = Query.suggest("", socket.assigns.conf)

      IO.inspect({parsed, params})

      {:noreply,
       socket
       |> assign(buffer: "", loading: false, suggestions: suggestions)
       |> push_patch(to: oban_path(:jobs, params))}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  def handle_info({ref, suggestions}, socket) when is_reference(ref) do
    {:noreply, assign(socket, loading: false, suggestions: suggestions)}
  end

  defp async_suggest(socket, buffer) do
    self = self()

    fun = fn ->
      suggestions = Query.suggest(buffer, socket.assigns.conf, resolver: socket.assigns.resolver)

      assigns =
        socket.assigns
        |> Map.take(~w(id conf params resolver)a)
        |> Map.put(:loading, false)
        |> Map.put(:suggestions, suggestions)

      send_update(self, __MODULE__, assigns)
    end

    fun
    |> Task.async()
    |> Task.yield(@spinner_timeout)
    |> case do
      nil -> assign(socket, loading: true)
      _ok -> socket
    end
  end
end
