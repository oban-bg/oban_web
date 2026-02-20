defmodule Oban.Web.Jobs.NewComponent do
  use Oban.Web, :live_component

  import Oban.Web.FormComponents

  @fields ~w(args max_attempts priority queue scheduled_at tags worker)a

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id="new-job"
      class="relative z-50 hidden"
      phx-mounted={show_drawer()}
      phx-remove={hide_drawer()}
      phx-window-keydown="keydown"
      phx-target={@myself}
    >
      <div
        id="new-job-bg"
        class="bg-zinc-50/80 dark:bg-zinc-950/80 fixed inset-0 hidden transition-opacity"
        aria-hidden="true"
        phx-click="close"
        phx-target={@myself}
      />

      <div class="fixed inset-0 overflow-hidden">
        <div class="absolute inset-0 overflow-hidden">
          <div class="pointer-events-none fixed inset-y-0 right-0 flex max-w-full pl-10">
            <div
              id="new-job-panel"
              class="pointer-events-auto w-screen max-w-md hidden transition-transform translate-x-full"
            >
              <div class="flex h-full flex-col overflow-y-scroll bg-white dark:bg-gray-900 shadow-xl">
                <div class="flex items-center justify-between px-4 py-4 border-b border-gray-200 dark:border-gray-700">
                  <h2 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
                    New Job
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
                  />

                  <.form_field
                    label="Args"
                    name="args"
                    value={@form.args}
                    type="textarea"
                    placeholder="{}"
                    required={true}
                    rows={3}
                  />

                  <.select_field
                    label="Queue"
                    name="queue"
                    value={@form.queue}
                    options={queue_options(@queues)}
                  />

                  <div class="grid grid-cols-2 gap-4">
                    <.form_field
                      label="Priority"
                      name="priority"
                      value={@form.priority}
                      type="number"
                      placeholder="0"
                      hint="0 (highest) to 9 (lowest)"
                    />

                    <.form_field
                      label="Max Attempts"
                      name="max_attempts"
                      value={@form.max_attempts}
                      type="number"
                      placeholder="20"
                    />
                  </div>

                  <.form_field
                    label="Scheduled At"
                    name="scheduled_at"
                    value={@form.scheduled_at}
                    type="datetime-local"
                    hint="Leave empty to run immediately"
                  />

                  <.form_field label="Tags" name="tags" value={@form.tags} placeholder="tag1, tag2" />

                  <div class="pt-4">
                    <button
                      type="submit"
                      class="w-full px-4 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 cursor-pointer"
                    >
                      Create Job
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

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn -> default_form() end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("form-change", params, socket) do
    form = Map.new(@fields, fn key -> {key, params[to_string(key)]} end)

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("create-job", params, socket) do
    enforce_access!(:insert_jobs, socket.assigns.access)

    %{conf: conf} = socket.assigns

    with {:ok, worker} <- parse_worker(params["worker"]),
         {:ok, args} <- parse_args(params["args"]),
         {:ok, opts} <- build_opts(params) do
      changeset = Oban.Job.new(args, [{:worker, worker} | opts])

      case Oban.insert(conf.name, changeset) do
        {:ok, job} ->
          send(self(), {:flash, :info, "Job created successfully"})
          {:noreply, push_patch(socket, to: oban_path([:jobs, job.id]))}

        {:error, changeset} ->
          message = format_changeset_error(changeset)
          send(self(), {:flash, :error, "Failed to create job: #{message}"})
          {:noreply, socket}
      end
    else
      {:error, message} ->
        send(self(), {:flash, :error, message})
        {:noreply, socket}
    end
  end

  def handle_event("close", _params, socket) do
    {:noreply, push_patch(socket, to: oban_path(:jobs))}
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    {:noreply, push_patch(socket, to: oban_path(:jobs))}
  end

  def handle_event("keydown", _params, socket) do
    {:noreply, socket}
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
  end

  # Helpers

  defp default_form do
    @fields
    |> Map.new(&{&1, ""})
    |> Map.put(:args, "{}")
  end

  defp parse_worker(worker) when is_binary(worker) and worker != "" do
    {:ok, String.trim(worker)}
  end

  defp parse_worker(_), do: {:error, "Worker is required"}

  defp parse_args(args) when is_binary(args) do
    case parse_json(args) do
      nil -> {:error, "Args must be a valid JSON object"}
      map -> {:ok, map}
    end
  end

  defp parse_args(_), do: {:error, "Args must be a valid JSON object"}

  defp build_opts(params) do
    queue = if params["queue"] in [nil, ""], do: "default", else: params["queue"]
    opts = [queue: queue]

    opts =
      case parse_int(params["priority"]) do
        nil -> opts
        priority when priority >= 0 and priority <= 9 -> Keyword.put(opts, :priority, priority)
        _ -> opts
      end

    opts =
      case parse_int(params["max_attempts"]) do
        nil -> opts
        max_attempts -> Keyword.put(opts, :max_attempts, max_attempts)
      end

    opts =
      case parse_scheduled_at(params["scheduled_at"]) do
        nil -> opts
        scheduled_at -> Keyword.put(opts, :scheduled_at, scheduled_at)
      end

    opts =
      case parse_tags(params["tags"]) do
        nil -> opts
        tags -> Keyword.put(opts, :tags, tags)
      end

    {:ok, opts}
  end

  defp parse_scheduled_at(nil), do: nil
  defp parse_scheduled_at(""), do: nil

  defp parse_scheduled_at(str) when is_binary(str) do
    case NaiveDateTime.from_iso8601(str <> ":00") do
      {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
      _ -> nil
    end
  end

  defp format_changeset_error(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {key, errors} -> "#{key} #{Enum.join(errors, ", ")}" end)
  end
end
