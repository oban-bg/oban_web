defmodule ObanWeb.Query do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Beat, Job}

  @default_queue "any"
  @default_state "executing"
  @default_limit 30

  def jobs(repo, opts) when is_map(opts), do: jobs(repo, Keyword.new(opts))

  def jobs(repo, opts) do
    queue = Keyword.get(opts, :queue, @default_queue)
    state = Keyword.get(opts, :state, @default_state)
    limit = Keyword.get(opts, :limit, @default_limit)
    terms = Keyword.get(opts, :terms)

    Job
    |> filter_state(state)
    |> filter_queue(queue)
    |> filter_terms(terms)
    |> order_state(state)
    |> limit(^limit)
    |> repo.all()
    |> Enum.map(&relativize_timestamps/1)
  end

  defp filter_state(query, state), do: where(query, state: ^state)

  defp filter_queue(query, "any"), do: query
  defp filter_queue(query, queue), do: where(query, queue: ^queue)

  defp filter_terms(query, nil), do: query

  defp filter_terms(query, terms) do
    ilike = terms <> "%"

    where(
      query,
      [j],
      fragment("? ~~* ?", j.worker, ^ilike) or
        fragment("? % ?", j.worker, ^terms) or
        fragment("to_tsvector('english', ?::text) @@ to_tsquery('english', ?)", j.args, ^terms)
    )
  end

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
      relative_attempted_at: maybe_diff(now, job.attempted_at),
      relative_completed_at: maybe_diff(now, job.completed_at),
      relative_inserted_at: maybe_diff(now, job.inserted_at),
      relative_scheduled_at: maybe_diff(now, job.scheduled_at)
    }

    Map.merge(job, relative)
  end

  defp maybe_diff(_now, nil), do: nil
  defp maybe_diff(now, then), do: NaiveDateTime.diff(now, then)

  @doc false
  def queue_counts(repo) do
    Job
    |> group_by([j], [j.queue, j.state])
    |> select([j], {j.queue, j.state, count(j.id)})
    |> where([j], j.state in ["available", "executing"])
    |> repo.all()
  end

  @doc false
  def state_counts(repo) do
    Job
    |> group_by([j], j.state)
    |> select([j], {j.state, count(j.id)})
    |> repo.all()
  end

  @doc false
  def node_counts(repo, seconds \\ 60) do
    since = DateTime.add(DateTime.utc_now(), -seconds)

    subquery =
      from b in Beat,
        select: %{node: b.node, queue: b.queue, running: b.running, rank: over(rank(), :nq)},
        windows: [nq: [partition_by: [b.node, b.queue], order_by: [desc: b.inserted_at]]],
        where: b.inserted_at > ^since

    query =
      from x in subquery(subquery),
        where: x.rank == 1,
        select: {x.node, x.queue, fragment("coalesce(array_length(?, 1), 0)", x.running)}

    repo.all(query)
  end
end
