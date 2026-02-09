defmodule Oban.Web.Crons.DetailComponent do
  use Oban.Web, :live_component

  alias Oban.Pro.Plugins.DynamicCron
  alias Oban.Web.CronExpr

  @compile {:no_warn_undefined, DynamicCron}

  database = :oban_web |> :code.priv_dir() |> Path.join("timezones.txt")

  @external_resource database

  @timezones database
             |> File.read!()
             |> String.split("\n", trim: true)

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="cron-details">
      <div class="flex justify-between items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700">
        <.link
          patch={oban_path(:crons, @params)}
          id="back-link"
          class="flex items-center hover:text-blue-500"
          data-title="Back to crons"
          phx-hook="Tippy"
        >
          <Icons.arrow_left class="w-5 h-5" />
          <span class="text-lg font-bold ml-2">{@cron.worker}</span>
        </.link>

        <div class="flex space-x-3">
          <button
            :if={@cron.dynamic? and can?(:pause_queues, @access)}
            type="button"
            class="flex items-center text-sm text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-800 px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-md focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 focus-visible:border-blue-500 hover:text-blue-500 hover:border-blue-600 cursor-pointer"
            phx-click="toggle-pause"
            phx-target={@myself}
          >
            <%= if @cron.paused? do %>
              <Icons.play_circle class="mr-2 h-5 w-5" /> Resume
            <% else %>
              <Icons.pause_circle class="mr-2 h-5 w-5" /> Pause
            <% end %>
          </button>

          <div :if={@cron.dynamic?} class="flex items-center">
            <span class="inline-flex items-center px-4 py-2 border border-transparent rounded-md text-sm font-medium bg-violet-100 text-violet-700 dark:bg-violet-900/50 dark:text-violet-300">
              <Icons.sparkles class="mr-1 h-4 w-4" /> Dynamic
            </span>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-3 gap-6 px-3 py-6">
        <div class="col-span-2">
          <div class="h-48 bg-gray-50 dark:bg-gray-800 rounded-md flex items-center justify-center">
            <span class="text-gray-400 text-sm">
              Spark chart placeholder - execution history will be displayed here
            </span>
          </div>
        </div>

        <div class="col-span-1">
          <div class="flex justify-between mb-6 pr-6">
            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Last Run
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                <span
                  id="cron-last-time"
                  data-timestamp={maybe_to_unix(@cron.last_at)}
                  phx-hook="Relativize"
                  phx-update="ignore"
                >
                  -
                </span>
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Next Run
              </span>
              <span class="text-base text-gray-800 dark:text-gray-200">
                <span
                  id="cron-next-time"
                  data-timestamp={maybe_to_unix(@cron.next_at)}
                  phx-hook="Relativize"
                  phx-update="ignore"
                >
                  -
                </span>
              </span>
            </div>

            <div class="flex flex-col">
              <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
                Last Status
              </span>
              <div class="flex items-center space-x-1">
                <.state_icon state={@cron.last_state} />
                <span class="text-base text-gray-800 dark:text-gray-200">
                  {state_label(@cron.last_state)}
                </span>
              </div>
            </div>
          </div>

          <div class="flex flex-col">
            <span class="uppercase font-semibold text-xs text-gray-500 dark:text-gray-400 mb-1">
              Schedule
            </span>
            <span class="text-base text-gray-800 dark:text-gray-200">
              <code class="font-mono">{@cron.expression}</code>
              <span :if={CronExpr.describe(@cron.expression)} class="ml-2 text-gray-500 dark:text-gray-400">
                ({CronExpr.describe(@cron.expression)})
              </span>
            </span>
          </div>
        </div>
      </div>

      <div class="px-3 py-6 border-t border-gray-200 dark:border-gray-700">
        <h3 class="flex font-semibold mb-3 space-x-2 text-gray-400">
          <Icons.pencil_square />
          <span>Edit Configuration</span>
        </h3>

        <fieldset disabled={not @cron.dynamic?}>
          <form
            id="cron-form"
            class="grid grid-cols-3 gap-6 bg-gray-50 dark:bg-gray-800 rounded-md p-4"
            phx-change="form-change"
            phx-submit="save-cron"
            phx-target={@myself}
          >
            <.form_field label="Schedule" name="expression" value={@cron.expression} />

            <.select_field
              label="Queue"
              name="queue"
              value={get_opt(@cron, "queue") || "default"}
              options={queue_options(@queues)}
            />

            <.select_field
              label="Timezone"
              name="timezone"
              value={get_opt(@cron, "timezone") || "Etc/UTC"}
              options={timezone_options(get_opt(@cron, "timezone"))}
              disabled={not @cron.dynamic?}
            />

            <.form_field label="Priority" name="priority" value={get_opt(@cron, "priority")} type="number" placeholder="0" />

            <.form_field label="Max Attempts" name="max_attempts" value={get_opt(@cron, "max_attempts")} type="number" placeholder="20" />

            <.form_field label="Tags" name="tags" value={format_tags(@cron)} placeholder="tag1, tag2" />

            <.form_field label="Args" name="args" value={format_args(@cron)} colspan="col-span-2" type="textarea" placeholder="{}" />

            <div class="col-span-1 pt-7 flex items-center">
              <.save_button cron={@cron} />
            </div>
          </form>
        </fieldset>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :colspan, :string, default: "col-span-1"
  attr :placeholder, :string, default: nil

  defp form_field(assigns) do
    ~H"""
    <div class={@colspan}>
      <label for={@name} class="block font-medium text-sm text-gray-700 dark:text-gray-300 mb-2">
        {@label}
      </label>
      <%= if @type == "textarea" do %>
        <textarea
          id={@name}
          name={@name}
          rows="3"
          placeholder={@placeholder}
          class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500"
        >{@value}</textarea>
      <% else %>
        <input
          type={@type}
          id={@name}
          name={@name}
          value={@value}
          placeholder={@placeholder}
          class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500"
        />
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :value, :any, default: nil
  attr :options, :list, required: true
  attr :disabled, :boolean, default: false

  defp select_field(assigns) do
    ~H"""
    <div>
      <label for={@name} class="block font-medium text-sm text-gray-700 dark:text-gray-300 mb-2">
        {@label}
      </label>
      <select
        id={@name}
        name={@name}
        disabled={@disabled}
        class="block w-full font-mono text-sm shadow-sm border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 rounded-md focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50"
      >
        <option :for={{label, val} <- @options} value={val} selected={val == @value}>
          {label}
        </option>
      </select>
    </div>
    """
  end

  attr :cron, :any, required: true

  defp save_button(assigns) do
    ~H"""
    <div class="flex items-center space-x-3">
      <button
        type="submit"
        disabled={not @cron.dynamic?}
        class="px-4 py-2 bg-blue-500 text-white text-sm font-medium rounded-md hover:bg-blue-600 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 cursor-pointer disabled:opacity-50 disabled:cursor-not-allowed"
      >
        Save Changes
      </button>
      <span :if={not @cron.dynamic?} rel="static-blocker" class="text-xs text-gray-500 dark:text-gray-400">
        <a
          href="https://hexdocs.pm/oban_pro/dynamic-cron.html"
          target="_blank"
          class="hover:underline"
        >
          Dynamic Only <Icons.arrow_top_right_on_square class="w-3 h-3 inline-block align-text-top" />
        </a>
      </span>
    </div>
    """
  end

  # Handlers

  @impl Phoenix.LiveComponent
  def handle_event("toggle-pause", _params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    %{cron: cron, conf: conf} = socket.assigns

    paused? = not cron.paused?

    DynamicCron.update(conf.name, cron.name, paused: paused?)

    {:noreply, assign(socket, cron: %{cron | paused?: paused?})}
  end

  def handle_event("form-change", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save-cron", params, socket) do
    enforce_access!(:pause_queues, socket.assigns.access)

    %{cron: cron, conf: conf} = socket.assigns

    opts =
      params
      |> parse_form_params(cron)
      |> Enum.reject(fn {_key, val} -> is_nil(val) end)

    case DynamicCron.update(conf.name, cron.name, opts) do
      {:ok, _entry} ->
        send(self(), :refresh)
        send(self(), {:flash, :info, "Cron configuration updated"})
        {:noreply, socket}

      {:error, _reason} ->
        send(self(), {:flash, :error, "Failed to update cron configuration"})
        {:noreply, socket}
    end
  end

  # Helpers

  defp queue_options(queues) do
    queues
    |> Enum.map(fn %{name: name} -> {name, name} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp timezone_options(_current_timezone) do
    Enum.map(@timezones, &{&1, &1})
  end

  defp parse_form_params(params, cron) do
    [
      expression: changed_val(params["expression"], cron.expression),
      queue: changed_val(parse_string(params["queue"]), get_opt(cron, "queue"), "default"),
      timezone: changed_val(parse_string(params["timezone"]), get_opt(cron, "timezone"), "Etc/UTC"),
      priority: changed_val(parse_int(params["priority"]), get_opt(cron, "priority")),
      max_attempts: changed_val(parse_int(params["max_attempts"]), get_opt(cron, "max_attempts")),
      tags: changed_val(parse_tags(params["tags"]), get_opt(cron, "tags")),
      args: changed_val(parse_json(params["args"]), get_opt(cron, "args"))
    ]
  end

  defp changed_val(new_val, current_val, default \\ nil)
  defp changed_val(nil, _current, _default), do: nil
  defp changed_val("", _current, _default), do: nil
  defp changed_val(val, val, _default), do: nil
  defp changed_val(val, nil, val), do: nil
  defp changed_val(val, _current, _default), do: val

  defp parse_string(nil), do: nil
  defp parse_string(""), do: nil
  defp parse_string(str), do: String.trim(str)

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil

  defp parse_int(str) do
    case Integer.parse(str) do
      {num, ""} -> num
      _ -> nil
    end
  end

  defp parse_tags(nil), do: nil
  defp parse_tags(""), do: nil

  defp parse_tags(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_json(nil), do: nil
  defp parse_json(""), do: nil

  defp parse_json(str) do
    case Oban.JSON.decode!(str) do
      map when is_map(map) -> map
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp maybe_to_unix(nil), do: ""

  defp maybe_to_unix(timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  defp get_opt(%{opts: opts}, key) do
    Map.get(opts, key)
  end

  defp format_tags(%{opts: %{"tags" => tags}}) when is_list(tags), do: Enum.join(tags, ", ")
  defp format_tags(_), do: nil

  defp format_args(%{opts: %{"args" => args}}) when is_map(args), do: Oban.JSON.encode!(args)
  defp format_args(_), do: nil

  defp state_label(nil), do: "Unknown"
  defp state_label(state), do: String.capitalize(state)

  attr :state, :string, required: true

  defp state_icon(%{state: nil} = assigns) do
    ~H"""
    <Icons.minus_circle class="w-5 h-5 text-gray-400" />
    """
  end

  defp state_icon(%{state: "available"} = assigns) do
    ~H"""
    <Icons.pause_circle class="w-5 h-5 text-teal-400" />
    """
  end

  defp state_icon(%{state: "cancelled"} = assigns) do
    ~H"""
    <Icons.x_circle class="w-5 h-5 text-violet-400" />
    """
  end

  defp state_icon(%{state: "completed"} = assigns) do
    ~H"""
    <Icons.check_circle class="w-5 h-5 text-cyan-400" />
    """
  end

  defp state_icon(%{state: "discarded"} = assigns) do
    ~H"""
    <Icons.exclamation_circle class="w-5 h-5 text-rose-400" />
    """
  end

  defp state_icon(%{state: "executing"} = assigns) do
    ~H"""
    <Icons.play_circle class="w-5 h-5 text-orange-400" />
    """
  end

  defp state_icon(%{state: "retryable"} = assigns) do
    ~H"""
    <Icons.arrow_path class="w-5 h-5 text-yellow-400" />
    """
  end

  defp state_icon(%{state: "scheduled"} = assigns) do
    ~H"""
    <Icons.play_circle class="w-5 h-5 text-emerald-400" />
    """
  end

  defp state_icon(assigns) do
    ~H"""
    <Icons.minus_circle class="w-5 h-5 text-gray-400" />
    """
  end
end
