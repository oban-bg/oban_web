defmodule Oban.Web.Live.Shortcuts do
  use Oban.Web, :live_component

  @impl Phoenix.LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id="shortcuts"
      class="relative z-50 hidden"
      data-shortcut={show_modal()}
      phx-hook="Shortcuts"
      phx-remove={hide_modal()}
      phx-target={@myself}
    >
      <div
        id="shortcuts-bg"
        class="bg-zinc-50/80 dark:bg-zinc-950/80 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />

      <div class="fixed inset-0 overflow-y-auto" role="dialog" aria-modal="true">
        <div class="flex min-h-full items-center justify-center">
          <div
            class="hidden w-full max-w-lg p-2 sm:p-4 relative rounded-md bg-white dark:bg-gray-950 shadow-lg ring-1 ring-zinc-700/10 transition"
            id="shortcuts-container"
            phx-click-away={hide_modal()}
            phx-key="escape"
            phx-window-keydown={hide_modal()}
          >
            <button
              phx-click={hide_modal()}
              type="button"
              class="absolute top-4 right-4 text-gray-400 hover:text-gray-600"
              aria-label="close"
            >
              <Icons.x_mark />
            </button>

            <div>
              <h3 class="font-semibold dark:text-gray-200 mb-4">Keyboard Shortcuts</h3>

              <dl class="divide-y divide-gray-100 dark:divide-gray-900 text-sm">
                <.list_item description="Go to jobs" shortcut="J" />
                <.list_item description="Go to queues" shortcut="Q" />

                <.list_item description="Focus search" shortcut="/" />
                <.list_item description="Toggle refresh" shortcut="r" />
                <.list_item description="Cycle themes" shortcut="t" />
                <.list_item description="Open this modal" shortcut="?" />
              </dl>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :description, :string, required: true
  attr :shortcut, :string, required: true

  defp list_item(assigns) do
    ~H"""
    <div class="py-4 flex justify-between">
      <dt class="text-gray-700 dark:text-gray-300 font-medium">{@description}</dt>
      <dd class="text-gray-700 dark:text-gray-300">
        <kbd class="px-2 py-1 bg-gray-50 dark:bg-gray-900 ring-1 ring-zinc-300 rounded-md">
          {@shortcut}
        </kbd>
      </dd>
    </div>
    """
  end

  # JS

  defp show_modal do
    %JS{}
    |> JS.show(to: "#shortcuts")
    |> JS.show(
      to: "#shortcuts-bg",
      transition: {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "#shortcuts-container",
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
    |> JS.add_class("overflow-hidden", to: "body")
  end

  defp hide_modal do
    %JS{}
    |> JS.hide(
      to: "#shortcuts-bg",
      transition: {"transition-all transform ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "#shortcuts-container",
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
    |> JS.hide(to: "#shortcuts", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end
end
