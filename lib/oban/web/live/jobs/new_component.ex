defmodule Oban.Web.Jobs.NewComponent do
  use Oban.Web, :live_component

  import Oban.Web.FormComponents

  alias Oban.Web.Jobs.Form

  @impl Phoenix.LiveComponent
  def render(assigns) do
    assigns = assign(assigns, :changed?, assigns.form != Form.seed())

    ~H"""
    <div
      id="new-job"
      class="relative z-50 hidden"
      phx-mounted={show_drawer()}
      phx-remove={hide_drawer()}
      phx-window-keydown={JS.dispatch("click", to: "#new-job-close")}
      phx-key="escape"
    >
      <div
        id="new-job-bg"
        class="bg-zinc-50/80 dark:bg-zinc-950/80 fixed inset-0 hidden transition-opacity"
        aria-hidden="true"
        data-confirm={@changed? && "Discard this unsaved job?"}
        phx-click="close"
        phx-target={@myself}
      />

      <div class="fixed inset-0 overflow-hidden">
        <div class="absolute inset-0 overflow-hidden">
          <div class="pointer-events-none fixed inset-y-0 right-0 flex max-w-full pl-10">
            <div
              id="new-job-panel"
              class="pointer-events-auto w-screen max-w-md hidden transition-transform translate-x-full"
              role="dialog"
              aria-modal="true"
              aria-labelledby="new-job-title"
            >
              <.focus_wrap
                id="new-job-focus"
                class="flex h-full flex-col overflow-y-scroll bg-white dark:bg-gray-900 shadow-xl"
              >
                <div class="flex items-center justify-between px-4 py-4 border-b border-gray-200 dark:border-gray-700">
                  <h2
                    id="new-job-title"
                    class="text-lg font-semibold text-gray-900 dark:text-gray-100"
                  >
                    New Job
                  </h2>
                  <button
                    id="new-job-close"
                    type="button"
                    class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 cursor-pointer"
                    data-confirm={@changed? && "Discard this unsaved job?"}
                    phx-click="close"
                    phx-target={@myself}
                    aria-label="Close"
                  >
                    <Icons.icon name="icon-x-mark" class="h-6 w-6" />
                  </button>
                </div>

                <div
                  :if={@errors != []}
                  id="new-job-errors"
                  role="alert"
                  class="px-4 py-3 bg-red-50 dark:bg-red-900/20 text-sm text-red-700 dark:text-red-300 space-y-1"
                >
                  <p :for={error <- @errors}>{error}</p>
                </div>

                <form
                  id="new-job-form"
                  class="flex-1 px-4 py-6 space-y-4"
                  phx-change="form-change"
                  phx-submit="create-job"
                  phx-target={@myself}
                >
                  <.form_field
                    label="Worker"
                    name="worker"
                    value={@form.worker}
                    placeholder="MyApp.Workers.SomeWorker"
                    required={true}
                    invalid={:worker in @invalid}
                  />

                  <.form_field
                    label="Args"
                    name="args"
                    value={@form.args}
                    type="textarea"
                    placeholder="{}"
                    required={true}
                    rows={3}
                    invalid={:args in @invalid}
                  />

                  <.select_field
                    label="Queue"
                    name="queue"
                    value={@form.queue}
                    options={queue_options(@queues)}
                    invalid={:queue in @invalid}
                  />

                  <div class="grid grid-cols-2 gap-4">
                    <.form_field
                      label="Priority"
                      name="priority"
                      value={@form.priority}
                      type="number"
                      min={0}
                      max={9}
                      placeholder="0"
                      hint="0 (highest) to 9 (lowest)"
                      invalid={:priority in @invalid}
                    />

                    <.form_field
                      label="Max Attempts"
                      name="max_attempts"
                      value={@form.max_attempts}
                      type="number"
                      min={1}
                      placeholder="20"
                      invalid={:max_attempts in @invalid}
                    />
                  </div>

                  <.form_field
                    label="Scheduled At"
                    name="scheduled_at"
                    value={@form.scheduled_at}
                    type="datetime-local"
                    hint="Leave empty to run immediately"
                    invalid={:scheduled_at in @invalid}
                  />

                  <.form_field
                    label="Tags"
                    name="tags"
                    value={@form.tags}
                    placeholder="tag1, tag2"
                    invalid={:tags in @invalid}
                  />

                  <div class="pt-4">
                    <button
                      type="submit"
                      disabled={not can?(:insert_jobs, @access)}
                      class="w-full px-4 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      Create Job
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
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:errors, fn -> [] end)
      |> assign_new(:form, fn -> Form.seed() end)
      |> assign_new(:invalid, fn -> [] end)

    {:ok, socket}
  end

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("form-change", params, socket) do
    form = Map.merge(socket.assigns.form, Form.cast_params(params))

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("create-job", params, socket) do
    enforce_access!(:insert_jobs, socket.assigns.access)

    %{conf: conf} = socket.assigns

    form = Map.merge(socket.assigns.form, Form.cast_params(params))
    socket = assign(socket, form: form)

    with {:ok, {worker, args, opts}} <- Form.build_insert(form),
         {:ok, job} <- Oban.insert(conf.name, build_changeset(worker, args, opts)) do
      send(self(), {:flash, :info, "Job created successfully"})

      {:noreply, push_patch(socket, to: oban_path([:jobs, job.id]))}
    else
      {:error, reason} ->
        {:noreply,
         assign(socket, errors: Form.format_failure(reason), invalid: Form.invalid_fields(reason))}
    end
  end

  def handle_event("close", _params, socket) do
    {:noreply, push_patch(socket, to: oban_path(:jobs))}
  end

  # JS Commands

  defp show_drawer do
    %JS{}
    |> JS.show(to: "#new-job")
    |> JS.show(
      to: "#new-job-bg",
      transition: {"ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "#new-job-panel",
      transition: {"ease-out duration-300", "translate-x-full", "translate-x-0"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.push_focus()
    |> JS.focus_first(to: "#new-job-form")
  end

  defp hide_drawer do
    %JS{}
    |> JS.hide(
      to: "#new-job-bg",
      transition: {"ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "#new-job-panel",
      time: 200,
      transition: {"ease-in duration-200", "translate-x-0", "translate-x-full"}
    )
    |> JS.hide(to: "#new-job", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
