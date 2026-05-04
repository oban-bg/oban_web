defmodule Oban.Web.Crons.Helpers do
  @moduledoc false

  use Phoenix.Component

  alias Oban.Web.Colors
  alias Oban.Web.Components.Icons

  attr :state, :string, required: true
  attr :paused, :boolean, default: false

  def state_icon(%{paused: true} = assigns) do
    ~H"""
    <Icons.icon name="icon-pause-circle" class="w-5 h-5 text-gray-400" />
    """
  end

  def state_icon(assigns) do
    assigns = assign(assigns, :color_class, Colors.state_text_class(assigns.state))

    ~H"""
    <%= case @state do %>
      <% "available" -> %>
        <Icons.icon name="icon-ellipsis-horizontal-circle" class={["w-5 h-5", @color_class]} />
      <% "cancelled" -> %>
        <Icons.icon name="icon-x-circle" class={["w-5 h-5", @color_class]} />
      <% "completed" -> %>
        <Icons.icon name="icon-check-circle" class={["w-5 h-5", @color_class]} />
      <% "discarded" -> %>
        <Icons.icon name="icon-exclamation-circle" class={["w-5 h-5", @color_class]} />
      <% "executing" -> %>
        <Icons.icon name="icon-play-circle" class={["w-5 h-5", @color_class]} />
      <% "retryable" -> %>
        <Icons.icon name="icon-arrow-path" class={["w-5 h-5", @color_class]} />
      <% "scheduled" -> %>
        <Icons.icon name="icon-clock" class={["w-5 h-5", @color_class]} />
      <% _ -> %>
        <Icons.icon name="icon-minus-circle" class="w-5 h-5 text-gray-400" />
    <% end %>
    """
  end

  @doc """
  Converts a NaiveDateTime to unix milliseconds, returning empty string for nil.
  """
  def maybe_to_unix(timestamp) when is_struct(timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  def maybe_to_unix(_timestamp), do: ""

  def show_name?(%{dynamic?: true, name: name, worker: worker}), do: name != worker
  def show_name?(_cron), do: false
end
