defmodule Oban.Web.Pruners.TableComponent do
  use Oban.Web, :live_component

  import Oban.Web.Pruners.Helpers

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div id="pruners-table" class="min-w-full">
      <ul class="flex items-center border-b border-gray-200 dark:border-gray-700 text-gray-400 dark:text-gray-500">
        <span class="w-7 shrink-0"></span>
        <.header label="rule" class="w-1/3 text-left" />
        <div class="ml-auto flex items-center space-x-6">
          <.header label="match" class="w-96 text-left" />
          <.header label="retention" class="w-32 text-right" />
          <.header label="limit" class="w-24 text-right" />
          <.header label="status" class="w-20 pr-4 text-right" />
        </div>
      </ul>

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
        <div class="mt-4">
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
          rule={rule}
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
  attr :rule, :map, required: true

  defp rule_row(assigns) do
    ~H"""
    <li
      id={"pruner-#{@rule.name}"}
      class={[
        "group flex items-center hover:bg-gray-50 dark:hover:bg-gray-950/30",
        @rule.paused && "opacity-60"
      ]}
    >
      <div class="w-7 shrink-0 flex flex-col items-center">
        <.move_button
          :if={not default?(@rule)}
          disabled={not @orderable? or @index == 0 or not can?(:update_pruners, @access)}
          icon="icon-chevron-up"
          id={"pruner-move-up-#{@rule.name}"}
          myself={@myself}
          name={@rule.name}
          offset={-1}
          title={move_title(@orderable?, "Match this rule earlier")}
        />
        <.move_button
          :if={not default?(@rule)}
          disabled={not @orderable? or @index == @last_movable or not can?(:update_pruners, @access)}
          icon="icon-chevron-down"
          id={"pruner-move-down-#{@rule.name}"}
          myself={@myself}
          name={@rule.name}
          offset={1}
          title={move_title(@orderable?, "Match this rule later")}
        />
      </div>

      <.link patch={oban_path([:pruners, @rule.name])} class="flex flex-grow items-center py-3.5">
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
              class="bg-blue-100 text-blue-700 dark:bg-blue-900/50 dark:text-blue-300"
            />
          </div>
        </div>

        <div class="ml-auto flex items-center space-x-6 tabular text-gray-500 dark:text-gray-300">
          <div class="w-96 flex flex-wrap items-center gap-1.5">
            <span
              :if={match_pairs(@rule) == []}
              class="text-sm italic text-gray-400 dark:text-gray-500"
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

          <div class="w-20 pr-4 flex justify-end">
            <span
              id={"pruner-status-#{@rule.name}"}
              data-title={if @rule.paused, do: "Paused", else: "Active"}
              phx-hook="Tippy"
            >
              <Icons.icon
                :if={@rule.paused}
                name="icon-pause-circle"
                class="w-5 h-5 text-gray-400"
                rel="is-paused"
              />
              <Icons.icon
                :if={not @rule.paused}
                name="icon-check-circle"
                class="w-5 h-5 text-green-500"
                rel="is-active"
              />
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
        "opacity-0 group-hover:opacity-100 transition-opacity",
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
end
