defmodule Oban.Web.Crons.NewComponent do
  use Oban.Web, :live_component

  import Oban.Web.Crons.Helpers
  import Oban.Web.FormComponents

  alias Oban.Pro.Plugins.DynamicCron
  alias Oban.Web.Timezones

  @compile {:no_warn_undefined, DynamicCron}

  @fields ~w(args expression max_attempts name priority queue tags timezone worker)a

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id="new-cron"
      class="relative z-50"
      phx-hook="NewCronDrawer"
      phx-remove={hide_drawer()}
      phx-window-keydown="keydown"
      phx-target={@myself}
    >
      <div
        id="new-cron-bg"
        class="bg-zinc-50/80 dark:bg-zinc-950/80 fixed inset-0"
        aria-hidden="true"
        phx-click="close"
        phx-target={@myself}
      />

      <div class="fixed inset-0 overflow-hidden">
        <div class="absolute inset-0 overflow-hidden">
          <div class="pointer-events-none fixed inset-y-0 right-0 flex max-w-full pl-10">
            <div id="new-cron-panel" class="pointer-events-auto w-screen max-w-md">
              <div class="flex h-full flex-col overflow-y-scroll bg-white dark:bg-gray-900 shadow-xl">
                <div class="flex items-center justify-between px-4 py-4 border-b border-gray-200 dark:border-gray-700">
                  <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
                    New Dynamic Cron
                  </h2>
                  <button
                    type="button"
                    class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 cursor-pointer"
                    phx-click="close"
                    phx-target={@myself}
                    aria-label="Close"
                  >
                    <Icons.x_mark class="h-6 w-6" />
                  </button>
                </div>

                <form
                  id="new-cron-form"
                  class="flex-1 px-4 py-6 space-y-4"
                  phx-change="form-change"
                  phx-submit="create-cron"
                  phx-target={@myself}
                >
                  <.form_field
                    label="Worker"
                    name="worker"
                    value={@form.worker}
                    placeholder="MyApp.Workers.SomeWorker"
                    required={true}
                  />

                  <.form_field
                    label="Name"
                    name="name"
                    value={@form.name}
                    placeholder="some-worker"
                    required={true}
                  />

                  <.form_field
                    label="Expression"
                    name="expression"
                    value={@form.expression}
                    placeholder="* * * * *"
                    required={true}
                  />

                  <.select_field
                    label="Queue"
                    name="queue"
                    value={@form.queue}
                    options={queue_options(@queues)}
                  />

                  <.select_field
                    label="Timezone"
                    name="timezone"
                    value={@form.timezone}
                    options={Timezones.options_with_blank()}
                  />

                  <div class="grid grid-cols-2 gap-4">
                    <.form_field
                      label="Priority"
                      name="priority"
                      value={@form.priority}
                      type="number"
                      placeholder="0"
                    />

                    <.form_field
                      label="Max Attempts"
                      name="max_attempts"
                      value={@form.max_attempts}
                      type="number"
                      placeholder="20"
                    />
                  </div>

                  <div class="grid grid-cols-2 gap-4">
                    <.form_field label="Tags" name="tags" value={@form.tags} placeholder="tag1, tag2" />

                    <div class="flex items-end pb-2">
                      <.checkbox_field
                        label="Guaranteed"
                        name="guaranteed"
                        checked={@form.guaranteed}
                      />
                    </div>
                  </div>

                  <.form_field
                    label="Args"
                    name="args"
                    value={@form.args}
                    type="textarea"
                    placeholder="{}"
                    rows={1}
                  />

                  <div class="pt-4">
                    <button
                      type="submit"
                      class="w-full px-4 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 cursor-pointer"
                    >
                      Create Cron
                    </button>
                  </div>
                </form>
              </div>
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
      |> assign_new(:form, fn -> default_form() end)

    {:ok, socket}
  end

  # Events

  @impl Phoenix.LiveComponent
  def handle_event("form-change", params, socket) do
    form = socket.assigns.form

    # Auto-generate name from worker if name is empty or matches previous auto-generated name
    name =
      if params["name"] == "" or params["name"] == form.name do
        worker_to_name(params["worker"])
      else
        params["name"]
      end

    form =
      @fields
      |> Map.new(fn key -> {key, params[to_string(key)]} end)
      |> Map.put(:name, name)
      |> Map.put(:guaranteed, params["guaranteed"] == "true")

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("create-cron", params, socket) do
    enforce_access!(:insert_jobs, socket.assigns.access)

    %{conf: conf} = socket.assigns

    with {:ok, worker} <- parse_worker(params["worker"]),
         {:ok, opts} <- build_opts(params) do
      case DynamicCron.insert(conf.name, [{params["expression"], worker, opts}]) do
        {:ok, _entries} ->
          send(self(), {:flash, :info, "Cron '#{params["name"]}' created successfully"})
          {:noreply, push_patch(socket, to: oban_path(:crons))}

        {:error, reason} ->
          send(self(), {:flash, :error, "Failed to create cron: #{inspect(reason)}"})
          {:noreply, socket}
      end
    else
      {:error, message} ->
        send(self(), {:flash, :error, message})
        {:noreply, socket}
    end
  end

  def handle_event("close", _params, socket) do
    {:noreply, push_patch(socket, to: oban_path(:crons))}
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    {:noreply, push_patch(socket, to: oban_path(:crons))}
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
  end

  # JS Commands

  defp hide_drawer do
    %JS{}
    |> JS.transition(
      {"transition-opacity ease-in duration-200", "opacity-100", "opacity-0"},
      to: "#new-cron-bg"
    )
    |> JS.transition(
      {"transition-transform ease-in duration-200", "translate-x-0", "translate-x-full"},
      to: "#new-cron-panel"
    )
    |> JS.remove_class("overflow-hidden", to: "body")
  end

  # Helpers

  defp default_form do
    @fields
    |> Map.new(&{&1, ""})
    |> Map.put(:guaranteed, false)
  end

  defp worker_to_name(""), do: ""

  defp worker_to_name(worker) do
    worker
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
    |> String.replace("_", "-")
  end

  defp parse_worker(worker) when is_binary(worker) and worker != "" do
    {:ok, String.to_atom("Elixir.#{worker}")}
  end

  defp parse_worker(_), do: {:error, "Worker is required"}

  defp build_opts(params) do
    opts = [name: params["name"]]

    opts =
      if params["guaranteed"] == "true" do
        Keyword.put(opts, :guaranteed, true)
      else
        opts
      end

    opts =
      if params["queue"] != "" do
        Keyword.put(opts, :queue, params["queue"])
      else
        opts
      end

    opts =
      if params["timezone"] != "" do
        Keyword.put(opts, :timezone, params["timezone"])
      else
        opts
      end

    opts =
      case parse_int(params["priority"]) do
        nil -> opts
        priority -> Keyword.put(opts, :priority, priority)
      end

    opts =
      case parse_int(params["max_attempts"]) do
        nil -> opts
        max_attempts -> Keyword.put(opts, :max_attempts, max_attempts)
      end

    opts =
      case parse_tags(params["tags"]) do
        nil -> opts
        tags -> Keyword.put(opts, :tags, tags)
      end

    opts =
      case parse_json(params["args"]) do
        nil -> opts
        args -> Keyword.put(opts, :args, args)
      end

    {:ok, opts}
  end
end
