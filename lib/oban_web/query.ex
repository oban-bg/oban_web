defmodule ObanWeb.Query do
  @moduledoc false

  import Ecto.Query

  alias Oban.Job

  def jobs(repo, opts) when is_map(opts), do: jobs(repo, Keyword.new(opts))

  def jobs(repo, opts) do
    queue = Keyword.get(opts, :queue, "any")
    state = Keyword.get(opts, :state, "executing")
    limit = Keyword.get(opts, :limit, 50)

    Job
    |> filter_state(state)
    |> filter_queue(queue)
    |> order_state(state)
    |> limit(^limit)
    |> repo.all()
    |> Enum.map(&relativize_timestamps/1)
  end

  defp filter_state(query, state), do: where(query, state: ^state)

  defp filter_queue(query, "any"), do: query
  defp filter_queue(query, queue), do: where(query, queue: ^queue)

  defp order_state(query, state) when state in ~w(retryable scheduled) do
    order_by(query, [j], desc: j.scheduled_at)
  end

  defp order_state(query, _state) do
    order_by(query, [j], asc: j.attempted_at)
  end

  # Once a job is attempted or scheduled the timestamp doesn't change. That prevents LiveView from
  # re-rendering the relative time, which makes it look like the view is broken. To work around
  # this issue we inject relative values to trigger change tracking.
  defp relativize_timestamps(%Job{} = job, now \\ NaiveDateTime.utc_now()) do
    relative = %{
      relative_attempted_at: NaiveDateTime.diff(now, job.attempted_at),
      relative_scheduled_at: NaiveDateTime.diff(now, job.scheduled_at)
    }

    Map.merge(job, relative)
  end

  def queue_counts(repo) do
    Job
    |> group_by([j], [j.queue, j.state])
    |> select([j], {j.queue, j.state, count(j.id)})
    |> where([j], j.state in ["available", "executing"])
    |> repo.all()
  end

  def state_counts(repo) do
    Job
    |> group_by([j], j.state)
    |> select([j], {j.state, count(j.id)})
    |> repo.all()
  end
end
