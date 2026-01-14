defmodule Oban.Web.NewJob.FormComponent do
  use Oban.Web, :live_component

  import Ecto.Query

  alias Oban.{Job, Repo}
  alias Oban.Web.{Cache, Telemetry}

  @default_inputs %{
    worker: "",
    args: "{}",
    queue: "default",
    priority: 0,
    tags: "",
    schedule_in: "",
    meta: "{}",
    max_attempts: 20,
    advanced: false
  }

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    queues = fetch_queues(assigns.conf)
    workers = fetch_workers(assigns.conf)

    socket =
      socket
      |> assign(assigns)
      |> assign(queues: queues, workers: workers)
      |> assign_new(:inputs, fn -> @default_inputs end)
      |> assign_new(:errors, fn -> %{} end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <form
      id="new-job-form"
      class="p-4 space-y-3"
      phx-target={@myself}
      phx-change="form-change"
      phx-submit="insert"
    >
      <div class="flex items-start gap-3">
        <div class="w-56">
          <label for="worker" class="block text-xs font-medium mb-1 dark:text-gray-200">
            Worker
          </label>
          <input
            type="text"
            id="worker"
            name="worker"
            list="worker-suggestions"
            value={@inputs.worker}
            autocomplete="off"
            placeholder="MyApp.Workers.SomeWorker"
            class={"w-full text-sm border rounded-md shadow-sm px-2 py-1.5 dark:bg-gray-800 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 #{if @errors[:worker], do: "border-red-400 dark:border-red-500", else: "border-gray-300 dark:border-gray-600"}"}
            phx-debounce="150"
          />
          <datalist id="worker-suggestions">
            <option :for={worker <- @workers} value={worker} />
          </datalist>
          <p :if={@errors[:worker]} class="mt-0.5 text-xs text-red-600 dark:text-red-400">
            {@errors[:worker]}
          </p>
        </div>

        <div class="w-32">
          <label for="queue" class="block text-xs font-medium mb-1 dark:text-gray-200">
            Queue
          </label>
          <select
            id="queue"
            name="queue"
            class="w-full text-sm border border-gray-300 dark:border-gray-600 dark:bg-gray-800 rounded-md shadow-sm px-2 py-1.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            <option :for={queue <- @queues} value={queue} selected={queue == @inputs.queue}>
              {queue}
            </option>
          </select>
        </div>

        <div class="flex-1 min-w-0">
          <label for="args" class="block text-xs font-medium mb-1 dark:text-gray-200">
            Args (JSON)
          </label>
          <textarea
            id="args"
            name="args"
            rows="1"
            placeholder="{}"
            class={"w-full font-mono text-sm border rounded-md shadow-sm px-2 py-1.5 dark:bg-gray-800 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-y #{if @errors[:args], do: "border-red-400 dark:border-red-500", else: "border-gray-300 dark:border-gray-600"}"}
            phx-debounce="300"
          >{@inputs.args}</textarea>
          <p :if={@errors[:args]} class="mt-0.5 text-xs text-red-600 dark:text-red-400">
            {@errors[:args]}
          </p>
        </div>
      </div>

      <div>
        <button
          type="button"
          class="flex items-center text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200"
          phx-click="toggle-advanced"
          phx-target={@myself}
        >
          <Icons.chevron_right :if={not @inputs.advanced} class="w-4 h-4 mr-1" />
          <Icons.chevron_down :if={@inputs.advanced} class="w-4 h-4 mr-1" /> Advanced Options
        </button>
      </div>

      <div
        :if={@inputs.advanced}
        class="space-y-2 pl-4 border-l-2 border-gray-200 dark:border-gray-700"
      >
        <div class="flex items-start gap-3">
          <div class="w-20">
            <label for="priority" class="block text-xs font-medium mb-1 dark:text-gray-200">
              Priority
            </label>
            <input
              type="number"
              id="priority"
              name="priority"
              min="0"
              max="9"
              value={@inputs.priority}
              class="w-full text-sm border border-gray-300 dark:border-gray-600 dark:bg-gray-800 rounded-md shadow-sm px-2 py-1.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <div class="w-24">
            <label for="max_attempts" class="block text-xs font-medium mb-1 dark:text-gray-200">
              Max Attempts
            </label>
            <input
              type="number"
              id="max_attempts"
              name="max_attempts"
              min="1"
              max="100"
              value={@inputs.max_attempts}
              class="w-full text-sm border border-gray-300 dark:border-gray-600 dark:bg-gray-800 rounded-md shadow-sm px-2 py-1.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <div class="w-28">
            <label for="schedule_in" class="block text-xs font-medium mb-1 dark:text-gray-200">
              Schedule In (s)
            </label>
            <input
              type="number"
              id="schedule_in"
              name="schedule_in"
              min="1"
              value={@inputs.schedule_in}
              placeholder=""
              class="w-full text-sm border border-gray-300 dark:border-gray-600 dark:bg-gray-800 rounded-md shadow-sm px-2 py-1.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <div class="flex-1 min-w-0">
            <label for="tags" class="block text-xs font-medium mb-1 dark:text-gray-200">
              Tags (comma-separated)
            </label>
            <input
              type="text"
              id="tags"
              name="tags"
              value={@inputs.tags}
              placeholder="tag1, tag2"
              class="w-full text-sm border border-gray-300 dark:border-gray-600 dark:bg-gray-800 rounded-md shadow-sm px-2 py-1.5 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>

          <div class="flex-1 min-w-0">
            <label for="meta" class="block text-xs font-medium mb-1 dark:text-gray-200">
              Meta (JSON)
            </label>
            <textarea
              id="meta"
              name="meta"
              rows="1"
              placeholder="{}"
              class={"w-full font-mono text-sm border rounded-md shadow-sm px-2 py-1.5 dark:bg-gray-800 focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-y #{if @errors[:meta], do: "border-red-400 dark:border-red-500", else: "border-gray-300 dark:border-gray-600"}"}
              phx-debounce="300"
            >{@inputs.meta}</textarea>
            <p :if={@errors[:meta]} class="mt-0.5 text-xs text-red-600 dark:text-red-400">
              {@errors[:meta]}
            </p>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-end space-x-3 pt-4 border-t border-gray-200 dark:border-gray-700">
        <button
          type="button"
          phx-click="cancel-form"
          phx-target={@myself}
          class="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100"
        >
          Cancel
        </button>

        <button
          type="submit"
          disabled={not can?(:insert_jobs, @access) or has_errors?(@errors)}
          class="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-md shadow-sm disabled:opacity-50 disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
        >
          Enqueue Job
        </button>
      </div>
    </form>
    """
  end

  defp has_errors?(errors), do: map_size(errors) > 0

  # Event Handlers

  @impl Phoenix.LiveComponent
  def handle_event("form-change", params, socket) do
    inputs = update_inputs(socket.assigns.inputs, params)
    errors = validate_inputs(inputs)

    {:noreply, assign(socket, inputs: inputs, errors: errors)}
  end

  def handle_event("toggle-advanced", _params, socket) do
    inputs = Map.update!(socket.assigns.inputs, :advanced, &not/1)
    {:noreply, assign(socket, inputs: inputs)}
  end

  def handle_event("cancel-form", _params, socket) do
    send(self(), :close_enqueue_form)
    {:noreply, socket}
  end

  def handle_event("insert", params, socket) do
    enforce_access!(:insert_jobs, socket.assigns.access)

    inputs = update_inputs(socket.assigns.inputs, params)
    errors = validate_inputs(inputs)

    if has_errors?(errors) do
      {:noreply, assign(socket, inputs: inputs, errors: errors)}
    else
      do_insert_job(inputs, socket)
    end
  end

  defp do_insert_job(inputs, socket) do
    case insert_job(inputs, socket.assigns.conf) do
      {:ok, job} ->
        Telemetry.action(:insert_job, socket, [job_id: job.id], fn -> :ok end)

        {:noreply, push_navigate(socket, to: oban_path([:jobs, job.id]))}

      {:error, changeset} ->
        errors = changeset_to_errors(changeset)
        {:noreply, assign(socket, errors: errors)}
    end
  end

  # Data Fetching

  defp fetch_queues(conf) do
    Cache.fetch(:enqueue_form_queues, fn ->
      query =
        Job
        |> select([j], j.queue)
        |> distinct(true)
        |> limit(100)

      Repo.all(conf, query)
    end)
    |> Enum.sort()
    |> then(fn queues ->
      if "default" in queues, do: queues, else: ["default" | queues]
    end)
  end

  defp fetch_workers(conf) do
    Cache.fetch(:enqueue_form_workers, fn ->
      query =
        Job
        |> select([j], j.worker)
        |> distinct(true)
        |> limit(500)

      Repo.all(conf, query)
    end)
    |> Enum.sort()
  end

  # Input Processing

  defp update_inputs(current, params) do
    %{
      current
      | worker: Map.get(params, "worker", current.worker),
        args: Map.get(params, "args", current.args),
        queue: Map.get(params, "queue", current.queue),
        priority: parse_int(params["priority"], current.priority),
        tags: Map.get(params, "tags", current.tags),
        schedule_in: Map.get(params, "schedule_in", current.schedule_in),
        meta: Map.get(params, "meta", current.meta),
        max_attempts: parse_int(params["max_attempts"], current.max_attempts)
    }
  end

  defp parse_int(nil, default), do: default
  defp parse_int("", default), do: default

  defp parse_int(val, default) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end

  # Validation

  defp validate_inputs(inputs) do
    errors = %{}

    errors =
      if String.trim(inputs.worker) == "" do
        Map.put(errors, :worker, "Worker is required")
      else
        errors
      end

    errors =
      case decode_json(inputs.args) do
        {:ok, _} -> errors
        {:error, _} -> Map.put(errors, :args, "Invalid JSON")
      end

    errors =
      case decode_json(inputs.meta) do
        {:ok, _} -> errors
        {:error, _} -> Map.put(errors, :meta, "Invalid JSON")
      end

    errors
  end

  defp decode_json(str) when str in ["", nil], do: {:ok, %{}}
  defp decode_json(str), do: Jason.decode(str)

  # Job Insertion

  defp insert_job(inputs, conf) do
    {:ok, args} = decode_json(inputs.args)
    {:ok, meta} = decode_json(inputs.meta)

    opts = build_job_opts(inputs, meta)
    changeset = Job.new(args, opts)

    Repo.insert(conf, changeset)
  end

  defp build_job_opts(inputs, meta) do
    opts = [
      worker: inputs.worker,
      queue: inputs.queue,
      priority: inputs.priority,
      max_attempts: inputs.max_attempts
    ]

    opts = maybe_add_tags(opts, inputs.tags)
    opts = maybe_add_schedule_in(opts, inputs.schedule_in)
    maybe_add_meta(opts, meta)
  end

  defp maybe_add_tags(opts, ""), do: opts

  defp maybe_add_tags(opts, tags) do
    tags =
      tags
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if Enum.any?(tags) do
      Keyword.put(opts, :tags, tags)
    else
      opts
    end
  end

  defp maybe_add_schedule_in(opts, ""), do: opts
  defp maybe_add_schedule_in(opts, nil), do: opts

  defp maybe_add_schedule_in(opts, schedule_in) when is_binary(schedule_in) do
    case Integer.parse(schedule_in) do
      {seconds, _} when seconds > 0 -> Keyword.put(opts, :schedule_in, seconds)
      _ -> opts
    end
  end

  defp maybe_add_meta(opts, meta) when meta == %{}, do: opts
  defp maybe_add_meta(opts, meta), do: Keyword.put(opts, :meta, meta)

  defp changeset_to_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Map.new(fn {k, v} -> {k, List.first(v)} end)
  end
end
