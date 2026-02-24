defmodule Oban.Web.Crons.Helpers do
  @moduledoc false

  use Phoenix.Component

  alias Oban.Web.Components.Icons

  attr :state, :string, required: true
  attr :paused, :boolean, default: false

  def state_icon(%{paused: true} = assigns) do
    ~H"""
    <Icons.pause_circle class="w-5 h-5 text-gray-400" />
    """
  end

  def state_icon(assigns) do
    ~H"""
    <%= case @state do %>
      <% "available" -> %>
        <Icons.ellipsis_horizontal_circle class="w-5 h-5 text-teal-400" />
      <% "cancelled" -> %>
        <Icons.x_circle class="w-5 h-5 text-violet-400" />
      <% "completed" -> %>
        <Icons.check_circle class="w-5 h-5 text-cyan-400" />
      <% "discarded" -> %>
        <Icons.exclamation_circle class="w-5 h-5 text-rose-400" />
      <% "executing" -> %>
        <Icons.play_circle class="w-5 h-5 text-orange-400" />
      <% "retryable" -> %>
        <Icons.arrow_path class="w-5 h-5 text-yellow-400" />
      <% "scheduled" -> %>
        <Icons.play_circle class="w-5 h-5 text-emerald-400" />
      <% _ -> %>
        <Icons.minus_circle class="w-5 h-5 text-gray-400" />
    <% end %>
    """
  end

  @doc """
  Converts a NaiveDateTime to unix milliseconds, returning empty string for nil.
  """
  def maybe_to_unix(nil), do: ""

  def maybe_to_unix(timestamp) do
    timestamp
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix(:millisecond)
  end

  def show_name?(%{dynamic?: true, name: name, worker: worker}), do: name != worker
  def show_name?(_cron), do: false
end
