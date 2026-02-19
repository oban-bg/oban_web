defmodule Oban.Web.Jobs.DetailComponent do
  use Oban.Web, :live_component

  import Oban.Web.Crons.Helpers,
    only: [parse_int: 1, parse_json: 1, parse_tags: 1, queue_options: 1]

  import Oban.Web.FormComponents

  alias Oban.Web.Jobs.{HistoryChartComponent, TimelineComponent}
  alias Oban.Web.{Resolver, Timing}

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:error_index, fn -> 0 end)
      |> assign_new(:error_sort, fn -> :desc end)
      |> assign_new(:edit_changed?, fn -> false end)
      |> assign_new(:queues, fn -> [] end)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="job-details">
      <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
        <button
          id="back-link"
          class="flex items-center hover:text-blue-500 cursor-pointer bg-transparent border-0 p-0"
          data-escape-back={true}
          data-title="Back to jobs"
          phx-hook="HistoryBack"
          type="button"
        >
          <Icons.arrow_left class="w-5 h-5" />
          <span class="text-lg font-bold ml-2">{job_title(@job)}</span>
        </button>

        <div class="flex space-x-3">
          <Core.status_badge :if={@job.meta["recorded"]} icon="camera" label="Recorded" />
          <Core.status_badge :if={@job.meta["encrypted"]} icon="lock_closed" label="Encrypted" />
          <Core.status_badge :if={@job.meta["structured"]} icon="table_cells" label="Structured" />
          <Core.status_badge :if={@job.meta["decorated"]} icon="sparkles" label="Decorated" />
          <Core.status_badge :if={@job.meta["rescued"]} icon="life_buoy" label="Rescued" />

          <Core.icon_button
            id="detail-cancel"
            icon="x_circle"
            label="Cancel"
            color="yellow"
            disabled={not cancelable?(@job)}
            phx-target={@myself}
            phx-click="cancel"
          />

          <Core.icon_button
            id="detail-retry"
            icon="arrow_path"
            label="Retry"
            color="blue"
            disabled={not (runnable?(@job) or retryable?(@job))}
            phx-target={@myself}
            phx-click="retry"
          />

          <Core.icon_button
            id="detail-delete"
            icon="trash"
            label="Delete"
            color="red"
            disabled={not deletable?(@job)}
            confirm="Are you sure you want to delete this job?"
            phx-target={@myself}
            phx-click="delete"
          />

          <Core.icon_button
            id="detail-edit"
            icon="pencil_square"
            label="Edit"
            color="violet"
            disabled={not editable?(@job)}
            phx-click={scroll_to_edit()}
          />
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-5 gap-6 px-3 pt-6">
        <div class="lg:col-span-3">
          <TimelineComponent.render job={@job} os_time={@os_time} />
        </div>

        <div class="lg:col-span-2">
          <div class="grid grid-cols-3 gap-4 mb-4 p-3 bg-gray-50 dark:bg-gray-800 rounded-md">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                ID
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200 tabular">
                {@job.id}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Wait Time
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {Timing.queue_time(@job)}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Exec Time
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {Timing.run_time(@job)}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Attempted By
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {attempted_by(@job)}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Snoozed
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {@job.meta["snoozed"] || "—"}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Rescued
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {@job.meta["rescued"] || "—"}
              </span>
            </div>
          </div>

          <div class="grid grid-cols-3 gap-4 mb-4 px-3">

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Queue
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {@job.queue}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Attempt
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {@job.attempt} of {@job.max_attempts}
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Priority
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                {@job.priority}
              </span>
            </div>
          </div>

          <div class="mt-4 px-3">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Args
              </span>
              <samp class="font-mono text-sm text-gray-600 dark:text-gray-300 line-clamp-2 break-all">
                {format_args(@job, @resolver)}
              </samp>
            </div>
          </div>
        </div>
      </div>

      <div class="px-3 py-6">
        <.live_component
          id="detail-history-chart"
          module={HistoryChartComponent}
          job={@job}
          history={@history}
        />
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <button
          id="errors-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
          phx-click={toggle_errors()}
        >
          <Icons.chevron_right
            id="errors-chevron"
            class={["w-5 h-5 transition-transform", if(Enum.any?(@job.errors), do: "rotate-90")]}
          />
          <span class="font-semibold">
            Errors
            <span :if={Enum.any?(@job.errors)} class="text-gray-400 font-normal">
              ({length(@job.errors)})
            </span>
          </span>
        </button>

        <div id="errors-content" class={["mt-3", if(Enum.empty?(@job.errors), do: "hidden")]}>
          <%= if Enum.any?(@job.errors) do %>
            <div class="flex items-center justify-end mb-3 space-x-4">
              <div class="flex items-center text-sm">
                <button
                  type="button"
                  phx-click="error-sort"
                  phx-value-sort="desc"
                  phx-target={@myself}
                  class={[
                    "px-2 py-1 cusror-pointer rounded-l-md border border-r-0 border-gray-300 dark:border-gray-600",
                    if(@error_sort == :desc,
                      do: "bg-gray-200 dark:bg-gray-700 text-gray-800 dark:text-gray-200",
                      else: "bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-750"
                    )
                  ]}
                >
                  Newest
                </button>
                <button
                  type="button"
                  phx-click="error-sort"
                  phx-value-sort="asc"
                  phx-target={@myself}
                  class={[
                    "px-2 py-1 cusror-pointer rounded-r-md border border-gray-300 dark:border-gray-600",
                    if(@error_sort == :asc,
                      do: "bg-gray-200 dark:bg-gray-700 text-gray-800 dark:text-gray-200",
                      else: "bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-750"
                    )
                  ]}
                >
                  Oldest
                </button>
              </div>

              <div class="flex items-center space-x-1">
                <button
                  type="button"
                  phx-click="error-nav"
                  phx-value-dir="prev"
                  phx-target={@myself}
                  disabled={@error_index == 0}
                  class={[
                    "p-1 rounded",
                    if(@error_index == 0,
                      do: "text-gray-300 dark:text-gray-600 cursor-not-allowed",
                      else: "text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
                    )
                  ]}
                >
                  <Icons.chevron_left class="w-5 h-5" />
                </button>
                <span class="text-sm text-gray-500 dark:text-gray-400 tabular min-w-[4rem] text-center">
                  {@error_index + 1} of {length(@job.errors)}
                </span>
                <button
                  type="button"
                  phx-click="error-nav"
                  phx-value-dir="next"
                  phx-target={@myself}
                  disabled={@error_index >= length(@job.errors) - 1}
                  class={[
                    "p-1 rounded",
                    if(@error_index >= length(@job.errors) - 1,
                      do: "text-gray-300 dark:text-gray-600 cursor-not-allowed",
                      else: "text-gray-500 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
                    )
                  ]}
                >
                  <Icons.chevron_right class="w-5 h-5" />
                </button>
              </div>
            </div>

            <.error_entry errors={@job.errors} index={@error_index} sort={@error_sort} />
          <% else %>
            <div class="flex items-center space-x-2 px-2 text-gray-400 dark:text-gray-500">
              <Icons.check_circle class="w-5 h-5" />
              <span class="text-sm">No errors recorded</span>
            </div>
          <% end %>
        </div>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <button
          id="meta-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
          phx-click={toggle_meta()}
        >
          <Icons.chevron_right
            id="meta-chevron"
            class={["w-5 h-5 transition-transform", if(meta_present?(@job), do: "rotate-90")]}
          />
          <span class="font-semibold">Meta</span>
        </button>

        <div id="meta-content" class={["mt-3", unless(meta_present?(@job), do: "hidden")]}>
          <div class="grid grid-cols-2 gap-6">
            <div>
              <h4 class="flex font-medium mb-2 text-xs uppercase text-gray-500 dark:text-gray-400">
                Job Meta
              </h4>
              <pre class="font-mono text-sm text-gray-500 dark:text-gray-400 whitespace-pre-wrap break-all">{format_meta(@job, @resolver)}</pre>
            </div>

            <div>
              <h4 class="flex font-medium mb-2 text-xs uppercase text-gray-500 dark:text-gray-400">
                Recorded Output
              </h4>
              <%= if @job.meta["recorded"] do %>
                <pre class="font-mono text-sm text-gray-600 dark:text-gray-400 whitespace-pre-wrap break-all"><%= format_recorded(@job, @resolver) %></pre>
              <% else %>
                <span class="text-sm text-gray-400 dark:text-gray-500">No recorded output</span>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <button
          id="edit-toggle"
          type="button"
          class="flex items-center w-full space-x-2 px-2 py-1.5 rounded-md text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 cursor-pointer"
          phx-click={toggle_edit()}
        >
          <Icons.chevron_right
            id="edit-chevron"
            class={["w-5 h-5 transition-transform", if(editable?(@job), do: "rotate-90")]}
          />
          <span class="font-semibold">Edit Job</span>
          <span
            :if={not editable?(@job)}
            id="edit-hint"
            class="flex items-center"
            data-title="Only available, scheduled, and retryable jobs can be edited"
            phx-hook="Tippy"
          >
            <Icons.info_circle class="w-4 h-4 text-gray-400" />
          </span>
        </button>

        <div id="edit-content" class={["mt-3", unless(editable?(@job), do: "hidden")]}>
          <fieldset disabled={not editable?(@job)}>
            <form
              id="job-edit-form"
              class="grid grid-cols-4 gap-4 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
              phx-change="edit-change"
              phx-submit="save-job"
              phx-target={@myself}
            >
              <.form_field label="Worker" name="worker" value={@job.worker} />

              <.select_field
                label="Queue"
                name="queue"
                value={@job.queue}
                options={queue_options(@queues)}
              />

              <.form_field
                label="Priority"
                name="priority"
                value={@job.priority}
                type="number"
                placeholder="0"
              />

              <.form_field
                label="Max Attempts"
                name="max_attempts"
                value={@job.max_attempts}
                type="number"
                placeholder="20"
              />

              <.form_field
                label="Scheduled At"
                name="scheduled_at"
                value={format_datetime(@job.scheduled_at)}
                type="datetime-local"
              />

              <.form_field
                label="Tags"
                name="tags"
                value={format_job_tags(@job.tags)}
                placeholder="tag1, tag2"
                colspan="col-span-3"
              />

              <.form_field
                label="Args"
                name="args"
                value={format_job_args(@job.args)}
                colspan="col-span-2"
                type="textarea"
                placeholder="{}"
                rows={3}
              />

              <.form_field
                label="Meta"
                name="meta"
                value={format_job_meta(@job.meta)}
                colspan="col-span-2"
                type="textarea"
                placeholder="{}"
                rows={3}
              />

              <div class="col-span-4 flex justify-end items-center gap-3 pt-4">
                <button
                  type="submit"
                  disabled={not @edit_changed?}
                  class="px-6 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Save Changes
                </button>
              </div>
            </form>
          </fieldset>
        </div>
      </div>
    </div>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("cancel", _params, socket) do
    if can?(:cancel_jobs, socket.assigns.access) do
      send(self(), {:cancel_job, socket.assigns.job})
    end

    {:noreply, socket}
  end

  def handle_event("delete", _params, socket) do
    if can?(:delete_jobs, socket.assigns.access) do
      send(self(), {:delete_job, socket.assigns.job})
    end

    {:noreply, socket}
  end

  def handle_event("retry", _params, socket) do
    if can?(:retry_jobs, socket.assigns.access) do
      send(self(), {:retry_job, socket.assigns.job})
    end

    {:noreply, socket}
  end

  def handle_event("error-sort", %{"sort" => sort}, socket) do
    sort = String.to_existing_atom(sort)

    {:noreply, assign(socket, error_sort: sort, error_index: 0)}
  end

  def handle_event("error-nav", %{"dir" => "prev"}, socket) do
    index = max(0, socket.assigns.error_index - 1)

    {:noreply, assign(socket, error_index: index)}
  end

  def handle_event("error-nav", %{"dir" => "next"}, socket) do
    max_index = length(socket.assigns.job.errors) - 1
    index = min(max_index, socket.assigns.error_index + 1)
    {:noreply, assign(socket, error_index: index)}
  end

  def handle_event("edit-change", params, socket) do
    changed? =
      params
      |> parse_edit_params(socket.assigns.job)
      |> Enum.any?(fn {_key, val} -> not is_nil(val) end)

    {:noreply, assign(socket, edit_changed?: changed?)}
  end

  def handle_event("save-job", params, socket) do
    job = socket.assigns.job

    changes =
      params
      |> parse_edit_params(job)
      |> Enum.reject(fn {_key, val} -> is_nil(val) end)
      |> Map.new()

    if map_size(changes) > 0 do
      send(self(), {:update_job, job, changes})
    end

    {:noreply, assign(socket, edit_changed?: false)}
  end

  # Helpers

  defp format_args(job, resolver) do
    Resolver.call_with_fallback(resolver, :format_job_args, [job])
  end

  defp format_meta(%{meta: meta} = job, resolver) do
    job =
      if meta["recorded"] do
        %{job | meta: Map.delete(meta, "return")}
      else
        job
      end

    Resolver.call_with_fallback(resolver, :format_job_meta, [job])
  end

  defp format_recorded(%{meta: meta} = job, resolver) do
    case meta do
      %{"recorded" => true, "return" => value} ->
        Resolver.call_with_fallback(resolver, :format_recorded, [value, job])

      %{"recorded" => true} ->
        "No Recording Yet"

      _ ->
        "Recording Not Enabled"
    end
  end

  defp error_entry(assigns) do
    error =
      assigns.errors
      |> Enum.sort_by(& &1["attempt"], assigns.sort)
      |> Enum.at(assigns.index)

    {message, stacktrace} = parse_error(error["error"])

    assigns = assign(assigns, error: error, message: message, stacktrace: stacktrace)

    ~H"""
    <div class="mb-8 p-4 bg-gray-50 dark:bg-gray-800 rounded-md">
      <div class="flex items-center justify-between mb-3 text-sm text-gray-500 dark:text-gray-400">
        <span>Attempt {@error["attempt"]}</span>
        <span>{Timing.datetime_to_words(@error["at"])} <span class="text-gray-400 dark:text-gray-500">({@error["at"]})</span></span>
      </div>

      <div class="font-mono text-base font-medium text-gray-800 dark:text-gray-200 mb-4">
        {@message}
      </div>

      <div :if={@stacktrace != []} class="space-y-1">
        <div
          :for={frame <- @stacktrace}
          class="font-mono text-sm text-gray-600 dark:text-gray-400 py-1.5 px-2 bg-white dark:bg-gray-900 rounded border-l-2 border-gray-300 dark:border-gray-600"
        >
          {frame}
        </div>
      </div>
    </div>
    """
  end

  defp parse_error(error) do
    case String.split(error, "\n", parts: 2) do
      [message, rest] ->
        stacktrace =
          rest
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        {message, stacktrace}

      [message] ->
        {message, []}
    end
  end

  defp toggle_errors do
    %JS{}
    |> JS.toggle(to: "#errors-content", in: "fade-in-scale", out: "fade-out-scale")
    |> JS.add_class("rotate-90", to: "#errors-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#errors-chevron.rotate-90")
  end

  defp toggle_meta do
    %JS{}
    |> JS.toggle(to: "#meta-content", in: "fade-in-scale", out: "fade-out-scale")
    |> JS.add_class("rotate-90", to: "#meta-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#meta-chevron.rotate-90")
  end

  defp meta_present?(%{meta: meta}) when map_size(meta) == 0, do: false
  defp meta_present?(_job), do: true

  defp job_title(job), do: Map.get(job.meta, "decorated_name", job.worker)

  defp toggle_edit do
    %JS{}
    |> JS.toggle(to: "#edit-content", in: "fade-in-scale", out: "fade-out-scale")
    |> JS.add_class("rotate-90", to: "#edit-chevron:not(.rotate-90)")
    |> JS.remove_class("rotate-90", to: "#edit-chevron.rotate-90")
  end

  defp scroll_to_edit do
    %JS{}
    |> JS.show(to: "#edit-content", transition: "fade-in-scale")
    |> JS.add_class("rotate-90", to: "#edit-chevron")
    |> JS.focus(to: "#job-edit-form input")
  end

  defp editable?(%{state: state}) do
    state in ~w(scheduled retryable available)
  end

  defp parse_edit_params(params, job) do
    [
      worker: new_val?(parse_string(params["worker"]), job.worker),
      queue: new_val?(parse_string(params["queue"]), job.queue),
      priority: new_val?(parse_int(params["priority"]), job.priority),
      max_attempts: new_val?(parse_int(params["max_attempts"]), job.max_attempts),
      scheduled_at: new_val?(parse_datetime(params["scheduled_at"]), job.scheduled_at),
      tags: new_val?(parse_tags(params["tags"]), job.tags),
      args: new_val?(parse_json(params["args"]), job.args),
      meta: new_val?(parse_json(params["meta"]), job.meta)
    ]
  end

  defp new_val?(nil, _current), do: nil
  defp new_val?("", _current), do: nil
  defp new_val?(val, val), do: nil
  defp new_val?(val, _current), do: val

  defp parse_string(nil), do: nil
  defp parse_string(""), do: nil
  defp parse_string(str), do: String.trim(str)

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(str) when is_binary(str) do
    case NaiveDateTime.from_iso8601(str <> ":00") do
      {:ok, datetime} -> datetime
      _ -> nil
    end
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_naive()
    |> format_datetime()
  end

  defp format_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
    |> String.slice(0, 16)
  end

  defp format_job_tags(nil), do: nil
  defp format_job_tags([]), do: nil
  defp format_job_tags(tags) when is_list(tags), do: Enum.join(tags, ", ")

  defp format_job_args(args) when is_map(args), do: Oban.JSON.encode!(args)
  defp format_job_args(_), do: "{}"

  defp format_job_meta(meta) when is_map(meta), do: Oban.JSON.encode!(meta)
  defp format_job_meta(_), do: "{}"
end
