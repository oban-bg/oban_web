defmodule Oban.Web.Query do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Config, Job, Repo}
  alias Oban.Web.Beat

  @default_node "any"
  @default_queue "any"
  @default_state "executing"
  @default_limit 30

  @timeout :timer.seconds(20)
  @minimum_pg_for_search 110_000

  defmacrop args_search(column, terms) do
    quote do
      fragment(
        """
        jsonb_to_tsvector(?, '["key","string"]') @@ websearch_to_tsquery(?)
        """,
        unquote(column),
        unquote(terms)
      )
    end
  end

  defmacro tags_search(column, terms) do
    quote do
      fragment(
        """
        to_tsvector(?::text) @@ websearch_to_tsquery(?)
        """,
        unquote(column),
        unquote(terms)
      )
    end
  end

  @doc false
  def fetch_job(%Config{} = conf, job_id) do
    case Repo.all(conf, where(Job, id: ^job_id)) do
      [] ->
        {:error, :not_found}

      [job] ->
        {:ok, relativize_timestamps(job)}
    end
  end

  @doc false
  def delete_jobs(%Config{} = conf, [_ | _] = job_ids) do
    Repo.delete_all(conf, where(Job, [j], j.id in ^job_ids))

    :ok
  end

  @doc false
  def deschedule_jobs(%Config{} = conf, [_ | _] = job_ids) do
    updates = [state: "available", completed_at: nil, discarded_at: nil]

    Repo.update_all(conf, where(Job, [j], j.id in ^job_ids), set: updates)

    :ok
  end

  @doc false
  def get_jobs(config, opts) when is_map(opts), do: get_jobs(config, Keyword.new(opts))

  def get_jobs(%Config{} = conf, opts) do
    node = Keyword.get(opts, :node, @default_node)
    queue = Keyword.get(opts, :queue, @default_queue)
    state = Keyword.get(opts, :state, @default_state)
    limit = Keyword.get(opts, :limit, @default_limit)
    terms = Keyword.get(opts, :terms)

    Job
    |> filter_node(node)
    |> filter_queue(queue)
    |> filter_state(state)
    |> filter_terms(terms, conf)
    |> order_state(state)
    |> limit(^limit)
    |> conf.repo.all(log: conf.log, prefix: conf.prefix)
    |> Enum.map(&relativize_timestamps/1)
  end

  defp filter_node(query, "any"), do: query

  defp filter_node(query, node) do
    where(query, [j], fragment("?[1] = ?", j.attempted_by, ^node))
  end

  defp filter_queue(query, "any"), do: query
  defp filter_queue(query, queue), do: where(query, queue: ^queue)

  defp filter_state(query, state), do: where(query, state: ^state)

  defp filter_terms(query, nil, _), do: query
  defp filter_terms(query, "", _), do: query

  defp filter_terms(query, terms, conf) do
    ilike = "%" <> terms <> "%"

    if pg_version(conf) >= @minimum_pg_for_search do
      where(
        query,
        [j],
        ilike(j.worker, ^ilike) or args_search(j.args, ^terms) or tags_search(j.tags, ^terms)
      )
    else
      where(query, [j], ilike(j.worker, ^ilike))
    end
  end

  defp order_state(query, state) when state in ~w(available retryable scheduled) do
    order_by(query, [j], asc: j.scheduled_at)
  end

  defp order_state(query, "executing") do
    order_by(query, [j], asc: j.attempted_at)
  end

  defp order_state(query, _state) do
    order_by(query, [j], desc: j.attempted_at)
  end

  # We need to know the PG server version to toggle full text search capabilities. Queries are
  # usually performed within a persistent LiveView connection, so we can safely cache the pg
  # version within that process.
  defp pg_version(%Config{} = conf) do
    case Process.get(:pg_version) do
      version when is_integer(version) ->
        version

      nil ->
        {:ok, %{rows: [[version]]}} =
          Repo.query(conf, "SELECT current_setting('server_version_num')::int", [])

        Process.put(:pg_version, version)

        version
    end
  end

  # Once a job is attempted or scheduled the timestamp doesn't change. That prevents LiveView from
  # re-rendering the relative time, which makes it look like the view is broken. To work around
  # this issue we inject relative values to trigger change tracking.
  defp relativize_timestamps(%Job{} = job, now \\ NaiveDateTime.utc_now()) do
    relative = %{
      relative_attempted_at: maybe_diff(now, job.attempted_at),
      relative_cancelled_at: maybe_diff(now, job.cancelled_at),
      relative_completed_at: maybe_diff(now, job.completed_at),
      relative_discarded_at: maybe_diff(now, job.discarded_at),
      relative_inserted_at: maybe_diff(now, job.inserted_at),
      relative_scheduled_at: maybe_diff(now, job.scheduled_at)
    }

    Map.merge(job, relative)
  end

  defp maybe_diff(_now, nil), do: nil
  defp maybe_diff(now, then), do: NaiveDateTime.diff(then, now)

  @doc false
  def node_counts(%Config{} = conf, seconds \\ 60) do
    since = DateTime.add(DateTime.utc_now(), -seconds)

    subquery =
      from b in Beat,
        select: %{
          node: b.node,
          queue: b.queue,
          running: b.running,
          limit: b.limit,
          paused: b.paused,
          rank: over(rank(), :nq)
        },
        windows: [nq: [partition_by: [b.node, b.queue], order_by: [desc: b.inserted_at]]],
        where: b.inserted_at > ^since

    query =
      from x in subquery(subquery, prefix: conf.prefix),
        where: x.rank == 1,
        select: {
          x.node,
          x.queue,
          fragment("coalesce(array_length(?, 1), 0)", x.running),
          x.limit,
          x.paused
        }

    Repo.all(conf, query, timeout: @timeout)
  end

  @doc false
  def queue_counts(%Config{} = conf) do
    query =
      Job
      |> group_by([j], [j.queue, j.state])
      |> select([j], {j.queue, j.state, count(j.id)})

    Repo.all(conf, query, timeout: @timeout)
  end
end
