defmodule ObanWeb.DashboardView do
  @moduledoc false

  use Phoenix.View, root: "lib/oban_web/templates", namespace: ObanWeb
  use Phoenix.HTML

  import Phoenix.LiveView, only: [live_component: 3]

  alias Oban.Job
  alias ObanWeb.Timing

  @doc """
  Extract the name of the node that attempted a job.
  """
  def attempted_by(%Job{attempted_by: nil}), do: "Not Attempted"
  def attempted_by(%Job{attempted_by: [node, _queue, _nonce]}), do: node

  @clearable_filter_types [:node, :queue, :worker]
  def clearable_filters(filters) do
    for {type, name} <- filters, type in @clearable_filter_types, name != "any" do
      {to_string(type), name}
    end
  end

  @doc """
  Select an absolute timestamp appropriate for the provided state and format it.
  """
  def absolute_time(state, job) do
    case state do
      "executing" -> "Attempted At: #{truncate_sec(job.attempted_at)}"
      "completed" -> "Completed At: #{truncate_sec(job.completed_at)}"
      "retryable" -> "Retryable At: #{truncate_sec(job.scheduled_at)}"
      "available" -> "Available At: #{truncate_sec(job.scheduled_at)}"
      "scheduled" -> "Scheduled At: #{truncate_sec(job.scheduled_at)}"
      "discarded" -> "Discarded At: #{truncate_sec(job.attempted_at || job.inserted_at)}"
    end
  end

  defp truncate_sec(datetime), do: NaiveDateTime.truncate(datetime, :second)

  @doc """
  Select a duration or distance in words based on the provided state.
  """
  def relative_time(state, job) do
    case state do
      "executing" -> Timing.to_duration(job.relative_attempted_at)
      "completed" -> Timing.to_words(job.relative_completed_at)
      "discarded" -> Timing.to_words(job.relative_attempted_at || job.relative_inserted_at)
      _ -> Timing.to_words(job.relative_scheduled_at)
    end
  end

  def integer_to_delimited(integer) when is_integer(integer) do
    integer
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3, 3, [])
    |> Enum.join(",")
    |> String.reverse()
  end

  def state_count(stats, state) do
    state
    |> :proplists.get_value(stats, %{count: 0})
    |> Map.get(:count)
  end

  def truncate(string, range \\ 0..90) do
    if String.length(string) > Enum.max(range) do
      String.slice(string, range) <> "…"
    else
      string
    end
  end
end
