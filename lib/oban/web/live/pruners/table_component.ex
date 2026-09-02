defmodule Oban.Web.Pruners.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Pruners.Helpers

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="pruners-table" class="min-w-full">
      <div class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-500">
        <span class="w-10 shrink-0"></span>
        <div class="flex flex-grow items-center">
          <.header label="rule" class="w-1/3 text-left" />
          <div class="ml-auto flex items-center space-x-6">
            <.header label="match" class="w-96 text-left" />
            <.header label="retention" class="w-32 text-right" />
            <.header label="limit" class="w-24 text-right" />
            <.header label="status" class="w-20 pr-4 text-right" />
          </div>
        </div>
      </div>

      <div
        :if={Enum.empty?(@rules) and @filtered?}
        id="pruners-no-matches"
        class="py-16 px-6 text-center"
      >
        <Icons.icon
          name="icon-magnifying-glass"
          class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500"
        />
        <h3 class="mt-4 text-xl font-semibold text-gray-900 dark:text-gray-100">
          No matching rules
        </h3>
        <p class="mt-2 text-base text-gray-500 dark:text-gray-400 max-w-md mx-auto">
          No pruning rules match the current filters.
        </p>
      </div>

      <div :if={Enum.empty?(@rules) and not @filtered?} class="py-16 px-6 text-center">
        <Icons.icon name="icon-trash" class="mx-auto h-12 w-12 text-gray-400 dark:text-gray-500" />
        <h3 class="mt-4 text-xl font-semibold text-gray-900 dark:text-gray-100">No pruning rules</h3>
        <p class="mt-2 text-base text-gray-500 dark:text-gray-400 max-w-md mx-auto">
          Nothing is being pruned. Rules are created from configuration when the pruner starts, or
          added here at runtime.
        </p>
        <div class="mt-6 flex items-center justify-center gap-5">
          <.link
            :if={can?(:insert_pruners, @access)}
            id="empty-new-rule"
            patch={oban_path([:pruners, :new])}
            class="h-10 flex items-center text-sm bg-white dark:bg-gray-800 px-3 py-2 border rounded-md text-gray-600 dark:text-gray-400 border-gray-300 dark:border-gray-700 hover:text-blue-500 hover:border-blue-600 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500 focus-visible:border-blue-500 cursor-pointer"
          >
            <Icons.icon name="icon-plus-circle" class="mr-1 h-4 w-4" /> Create a rule
          </.link>

          <a
            href="https://oban.pro/docs/pro/Oban.Pro.Pruner.html"
            target="_blank"
            rel="noopener"
            class="text-base font-medium text-violet-600 hover:text-violet-500 dark:text-violet-400 dark:hover:text-violet-300"
          >
            Learn about pruners <span aria-hidden="true">&rarr;</span>
          </a>
        </div>
      </div>

      <ul class="divide-y divide-gray-100 dark:divide-gray-800">
        <.rule_row
          :for={{rule, index} <- Enum.with_index(@rules)}
          access={@access}
          index={index}
          last_movable={last_movable(@rules)}
          myself={@myself}
          orderable?={@orderable?}
          position={position_of(rule, @chain)}
          rule={rule}
          shadowed?={not rule.paused and shadowed_by(rule, @chain) != []}
          status={@status}
        />
      </ul>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :class, :string, default: ""

  defp header(assigns) do
    ~H"""
    <span class={[@class, "text-xs font-medium uppercase tracking-wider py-1.5"]}>
      {@label}
    </span>
    """
  end

  attr :access, :any, required: true
  attr :index, :integer, required: true
  attr :last_movable, :integer, required: true
  attr :myself, :any, required: true
  attr :orderable?, :boolean, required: true
  attr :position, :integer, required: true
  attr :rule, :map, required: true
  attr :shadowed?, :boolean, required: true
  attr :status, :map, required: true

  defp rule_row(assigns) do
    ~H"""
    <li
      id={"pruner-#{dom_name(@rule)}"}
      class={[
        "group flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30",
        @rule.paused && "opacity-75"
      ]}
    >
      <div class="relative w-10 shrink-0 self-stretch flex flex-col items-stretch justify-center">
        <span
          class={[
            "text-xs text-center tabular text-gray-400 dark:text-gray-500",
            not default?(@rule) &&
              "absolute inset-0 flex items-center justify-center pointer-events-none transition-opacity group-hover:opacity-0 group-focus-within:opacity-0"
          ]}
          rel="position"
        >
          {@position}
        </span>

        <.move_button
          :if={not default?(@rule)}
          disabled={not @orderable? or @index == 0 or not can?(:update_pruners, @access)}
          icon="icon-chevron-up"
          id={"pruner-move-up-#{dom_name(@rule)}"}
          myself={@myself}
          name={@rule.name}
          offset={-1}
          title={move_title(@orderable?, "Match this rule earlier")}
        />
        <.move_button
          :if={not default?(@rule)}
          disabled={not @orderable? or @index == @last_movable or not can?(:update_pruners, @access)}
          icon="icon-chevron-down"
          id={"pruner-move-down-#{dom_name(@rule)}"}
          myself={@myself}
          name={@rule.name}
          offset={1}
          title={move_title(@orderable?, "Match this rule later")}
        />
      </div>

      <.link
        patch={oban_path([:pruners, @rule.name])}
        class="flex flex-grow items-center py-3.5 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-blue-500"
      >
        <div class="w-1/3 min-w-0">
          <span class="font-semibold text-sm text-gray-700 dark:text-gray-300">
            {@rule.name}
          </span>

          <div
            :if={default?(@rule) or @rule.archive}
            class="flex flex-wrap items-center gap-1.5 mt-1"
          >
            <.badge
              :if={default?(@rule)}
              label="default"
              rel="is-default"
              class="bg-gray-100 text-gray-600 dark:bg-gray-800 dark:text-gray-400"
            />
            <.badge
              :if={@rule.archive}
              label="archive"
              rel="is-archive"
              class="bg-violet-100 text-violet-700 dark:bg-violet-900/50 dark:text-violet-300"
            />
          </div>
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <div class="w-96 flex flex-wrap items-center gap-1.5">
            <span
              :if={match_pairs(@rule) == []}
              class="text-sm italic text-gray-500 dark:text-gray-400"
            >
              all jobs
            </span>

            <span
              :for={{field, value} <- match_pairs(@rule)}
              class="inline-flex items-center max-w-full rounded text-xs bg-gray-100 dark:bg-gray-800"
            >
              <span class="px-1.5 py-0.5 text-gray-500 dark:text-gray-400">{field}</span>
              <span class="px-1.5 py-0.5 font-medium text-gray-700 dark:text-gray-300 truncate">
                {value}
              </span>
            </span>
          </div>

          <span class="w-32 text-right text-sm">{format_mode(@rule)}</span>

          <span class="w-24 text-right text-sm">{estimate_limit(@rule)}</span>

          <div class="w-20 pr-4 flex items-center justify-end gap-1.5">
            <span
              :if={@shadowed?}
              id={"pruner-shadowed-#{dom_name(@rule)}"}
              data-title="Shadowed — earlier rules claim every job it matches"
              phx-hook="Tippy"
            >
              <Icons.icon
                name="icon-exclamation-circle"
                class="w-5 h-5 text-amber-500 dark:text-amber-400"
                rel="is-shadowed"
              />
              <span class="sr-only">Shadowed by earlier rules</span>
            </span>

            <span
              id={"pruner-status-#{dom_name(@rule)}"}
              data-title={status_title(@rule, @status)}
              phx-hook="Tippy"
            >
              <Icons.icon
                :if={@rule.paused}
                name="icon-pause-circle"
                class="w-5 h-5 text-gray-400 dark:text-gray-500"
                rel="is-paused"
              />
              <Icons.icon
                :if={not @rule.paused and @status.configured?}
                name="icon-check-circle"
                class="w-5 h-5 text-emerald-600 dark:text-emerald-400"
                rel="is-active"
              />
              <Icons.icon
                :if={not @rule.paused and not @status.configured?}
                name="icon-minus-circle"
                class="w-5 h-5 text-gray-400 dark:text-gray-500"
                rel="is-stored"
              />
              <span class="sr-only">{status_title(@rule, @status)}</span>
            </span>
          </div>
        </div>
      </.link>
    </li>
    """
  end

  attr :disabled, :boolean, required: true
  attr :icon, :string, required: true
  attr :id, :string, required: true
  attr :myself, :any, required: true
  attr :name, :string, required: true
  attr :offset, :integer, required: true
  attr :title, :string, required: true

  defp move_button(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      disabled={@disabled}
      title={@title}
      phx-click="move-rule"
      phx-value-name={@name}
      phx-value-offset={@offset}
      phx-target={@myself}
      class={[
        "flex-1 min-h-0 flex items-center justify-center",
        "opacity-0 group-hover:opacity-100 group-focus-within:opacity-100 transition-opacity",
        "rounded focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-blue-500",
        if(@disabled,
          do: "text-gray-300 dark:text-gray-600 cursor-not-allowed",
          else: "text-gray-400 dark:text-gray-500 hover:text-blue-500 cursor-pointer"
        )
      ]}
    >
      <Icons.icon name={@icon} class="w-4 h-4" />
    </button>
    """
  end

  attr :label, :string, required: true
  attr :class, :string, required: true
  attr :rel, :string, required: true

  defp badge(assigns) do
    ~H"""
    <span
      class={["inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium", @class]}
      rel={@rel}
    >
      {@label}
    </span>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("move-rule", %{"name" => name, "offset" => offset}, socket) do
    enforce_access!(:update_pruners, socket.assigns.access)

    send(self(), {:move_rule, name, String.to_integer(offset)})

    {:noreply, socket}
  end

  # The default rule is pinned last, so it never counts toward movable positions.
  defp last_movable(rules) do
    Enum.count(rules, &(not default?(&1))) - 1
  end

  defp move_title(true, title), do: title

  defp move_title(_orderable?, _title) do
    "Clear filters and sort by order to change evaluation order"
  end

  defp status_title(%{paused: true}, _status), do: "Paused"
  defp status_title(_rule, %{configured?: true}), do: "Active"
  defp status_title(_rule, _status), do: "Stored — no pruner is running"
end
