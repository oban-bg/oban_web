defmodule Oban.Web.Pruners.NewComponent do
  use Oban.Web, :live_component

  import Oban.Web.FormComponents

  alias Oban.Web.Pruners.Form

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id="new-pruner"
      class="relative z-50 hidden"
      phx-mounted={show_drawer()}
      phx-remove={hide_drawer()}
      phx-window-keydown="keydown"
      phx-target={@myself}
    >
      <div
        id="new-pruner-bg"
        class="bg-zinc-50/80 dark:bg-zinc-950/80 fixed inset-0 hidden transition-opacity"
        aria-hidden="true"
        phx-click="close"
        phx-target={@myself}
      />

      <div class="fixed inset-0 overflow-hidden">
        <div class="absolute inset-0 overflow-hidden">
          <div class="pointer-events-none fixed inset-y-0 right-0 flex max-w-full pl-10">
            <div
              id="new-pruner-panel"
              class="pointer-events-auto w-screen max-w-md hidden transition-transform translate-x-full"
              role="dialog"
              aria-modal="true"
              aria-labelledby="new-pruner-title"
            >
              <.focus_wrap
                id="new-pruner-focus"
                class="flex h-full flex-col overflow-y-scroll bg-white dark:bg-gray-900 shadow-xl"
              >
                <div class="flex items-center justify-between px-4 py-4 border-b border-gray-200 dark:border-gray-700">
                  <h2
                    id="new-pruner-title"
                    class="text-lg font-semibold text-gray-900 dark:text-gray-100"
                  >
                    New Pruning Rule
                  </h2>
                  <button
                    type="button"
                    class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 cursor-pointer"
                    phx-click="close"
                    phx-target={@myself}
                    aria-label="Close"
                  >
                    <Icons.icon name="icon-x-mark" class="h-6 w-6" />
                  </button>
                </div>

                <div
                  :if={@errors != []}
                  id="new-pruner-errors"
                  class="px-4 py-3 bg-red-50 dark:bg-red-900/20 text-sm text-red-700 dark:text-red-300 space-y-1"
                >
                  <p :for={error <- @errors}>{error}</p>
                </div>

                <form
                  id="new-pruner-form"
                  class="flex-1 px-4 py-6 space-y-4"
                  phx-change="form-change"
                  phx-submit="save-rule"
                  phx-target={@myself}
                >
                  <.form_field
                    label="Name"
                    name="name"
                    value={@form.name}
                    placeholder="stale-events"
                    required={true}
                  />

                  <div class="grid grid-cols-2 gap-4">
                    <.form_field
                      label="Queue"
                      name="queue"
                      value={@form.queue}
                      placeholder="any queue"
                      hint="Only prune jobs from this queue"
                    />

                    <.form_field
                      label="Worker"
                      name="worker"
                      value={@form.worker}
                      placeholder="any worker"
                      hint="Only prune jobs for this worker"
                    />
                  </div>

                  <.select_field
                    label="State"
                    name="state"
                    value={@form.state}
                    options={Form.state_options()}
                  />

                  <.select_field
                    label="Retain"
                    name="kind"
                    value={@form.kind}
                    options={Form.kind_options()}
                  />

                  <div :if={@form.kind == "age"} class="grid grid-cols-2 gap-4">
                    <.form_field
                      label="Age"
                      name="age_value"
                      value={@form.age_value}
                      type="number"
                      min={1}
                      placeholder="7"
                      required={true}
                    />

                    <.select_field
                      label="Unit"
                      name="age_unit"
                      value={@form.age_unit}
                      options={Form.unit_options()}
                    />
                  </div>

                  <.form_field
                    :if={@form.kind == "length"}
                    label="Length"
                    name="length_value"
                    value={@form.length_value}
                    type="number"
                    min={1}
                    placeholder="1000"
                    required={true}
                    hint="Number of most recent jobs to keep"
                  />

                  <div class="grid grid-cols-2 gap-4">
                    <.form_field
                      label="Limit"
                      name="limit"
                      value={@form.limit}
                      type="number"
                      min={1}
                      max={Form.max_limit()}
                      placeholder="10000"
                      hint="Maximum jobs deleted per pass"
                    />

                    <.form_field
                      label="Timeout"
                      name="timeout"
                      value={@form.timeout}
                      type="number"
                      min={1}
                      placeholder="60000"
                      hint="Milliseconds each pass may spend deleting"
                    />
                  </div>

                  <.checkbox_field
                    label="Archive"
                    name="archive"
                    checked={@form.archive}
                    hint="Copy jobs into the archive table instead of discarding them"
                  />

                  <div class="pt-4">
                    <button
                      type="submit"
                      disabled={not can?(:insert_pruners, @access)}
                      class="w-full px-4 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      Create Rule
                    </button>
                  </div>
                </form>
              </.focus_wrap>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Callbacks

  @impl Phoenix.LiveComponent
  def update(%{failure: failure}, socket) do
    {:ok, assign(socket, errors: Form.format_failure(failure))}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:errors, fn -> [] end)
      |> assign_new(:form, fn -> Form.seed() end)

    {:ok, socket}
  end

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("form-change", params, socket) do
    form = Map.merge(socket.assigns.form, Form.cast_params(params))

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save-rule", params, socket) do
    enforce_access!(:insert_pruners, socket.assigns.access)

    form = Map.merge(socket.assigns.form, Form.cast_params(params))
    socket = assign(socket, form: form)

    case Form.build_opts(form) do
      {:ok, opts} ->
        send(self(), {:insert_rule, opts})

        {:noreply, assign(socket, errors: [])}

      {:error, message} ->
        {:noreply, assign(socket, errors: [message])}
    end
  end

  def handle_event("close", _params, socket) do
    {:noreply, push_patch(socket, to: oban_path(:pruners))}
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    {:noreply, push_patch(socket, to: oban_path(:pruners))}
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  # JS Commands

  defp show_drawer do
    %JS{}
    |> JS.show(to: "#new-pruner")
    |> JS.show(
      to: "#new-pruner-bg",
      transition: {"ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "#new-pruner-panel",
      transition: {"ease-out duration-300", "translate-x-full", "translate-x-0"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.push_focus()
    |> JS.focus_first(to: "#new-pruner-form")
  end

  defp hide_drawer do
    %JS{}
    |> JS.hide(
      to: "#new-pruner-bg",
      transition: {"ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "#new-pruner-panel",
      time: 200,
      transition: {"ease-in duration-200", "translate-x-0", "translate-x-full"}
    )
    |> JS.hide(to: "#new-pruner", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
