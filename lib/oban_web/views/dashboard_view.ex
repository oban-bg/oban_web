defmodule ObanWeb.DashboardView do
  use ObanWeb.Web, :view

  alias ObanWeb.{IconView, Timing}

  @doc """
  A helper for rendering icon templates from the IconView.
  """
  def icon(name) do
    render(IconView, name <> ".html")
  end

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
      "discarded" -> "Discarded At: #{truncate_sec(job.completed_at || job.inserted_at)}"
    end
  end

  defp truncate_sec(datetime), do: NaiveDateTime.truncate(datetime, :second)

  @doc """
  Select a duration or distance in words based on the provided state.
  """
  def relative_time(state, job) do
    case state do
      "attempted" -> Timing.to_words(job.relative_attempted_at)
      "completed" -> Timing.to_words(job.relative_completed_at)
      "discarded" -> Timing.to_words(job.relative_attempted_at || job.relative_inserted_at)
      "executing" -> Timing.to_duration(job.relative_attempted_at)
      "inserted" -> Timing.to_words(job.relative_inserted_at)
      _ -> Timing.to_words(job.relative_scheduled_at)
    end
  end

  def state_count(stats, state) do
    state
    |> :proplists.get_value(stats, %{count: 0})
    |> Map.get(:count)
  end
end
