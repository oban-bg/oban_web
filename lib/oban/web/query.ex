defmodule Oban.Web.Query do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Config, Job, Repo, Web.Search}

  @default_state "executing"
  @default_limit 30

  @minimum_pg_for_search 110_000
  @timeout :timer.seconds(20)

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
  def cancel_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Enum.each(job_ids, &Oban.cancel_job(name, &1))

    :ok
  end

  @doc false
  def delete_jobs(%Config{} = conf, [_ | _] = job_ids) do
    Repo.delete_all(conf, where(Job, [j], j.id in ^job_ids))

    :ok
  end

  @doc false
  def deschedule_jobs(%Config{} = conf, [_ | _] = job_ids) do
    query =
      Job
      |> where([j], j.id in ^job_ids)
      |> update([j],
        set: [
          state: "available",
          max_attempts: fragment("GREATEST(?, ? + 1)", j.max_attempts, j.attempt),
          scheduled_at: ^DateTime.utc_now(),
          completed_at: nil,
          cancelled_at: nil,
          discarded_at: nil
        ]
      )

    Repo.update_all(conf, query, [])

    :ok
  end

  @doc false
  def get_jobs(%Config{} = conf, %{} = args) do
    args =
      args
      |> Map.put_new(:limit, @default_limit)
      |> Map.put_new(:state, @default_state)

    query =
      args
      |> Enum.reduce(Job, &filter(&1, &2, conf))
      |> order_state(args[:state])
      |> limit(^args[:limit])

    conf
    |> Repo.all(query)
    |> Enum.map(&relativize_timestamps/1)
  end

  defp filter({:node, name_node}, query, _conf) do
    node =
      name_node
      |> String.split("/")
      |> List.last()

    where(query, [j], fragment("?[1] = ?", j.attempted_by, ^node))
  end

  defp filter({:queue, queue}, query, _conf), do: where(query, queue: ^queue)
  defp filter({:state, state}, query, _conf), do: where(query, state: ^state)

  defp filter({:terms, terms}, query, conf) when byte_size(terms) > 0 do
    if pg_version(conf) >= @minimum_pg_for_search do
      Search.build(query, terms)
    else
      where(query, [j], ilike(j.worker, ^"%#{terms}%"))
    end
  end

  defp filter(_, query, _conf), do: query

  defp order_state(query, state) when state in ~w(available retryable scheduled) do
    order_by(query, [j], asc: j.scheduled_at)
  end

  defp order_state(query, "executing") do
    order_by(query, [j], asc: j.attempted_at)
  end

  defp order_state(query, _state) do
    order_by(query, [j], desc: j.attempted_at)
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
  def queue_counts(%Config{} = conf) do
    per_queue_query =
      Job
      |> where([j], j.state in ["available", "executing"])
      |> group_by([j], [j.queue, j.state])
      |> select([j], {j.queue, j.state, count(j.id)})

    per_state_query =
      Job
      |> where([j], j.state not in ["available", "executing"])
      |> group_by([j], [j.state])
      |> select([j], {fragment("null"), j.state, count(j.id)})

    query = union(per_queue_query, ^per_state_query)

    Repo.all(conf, query, timeout: @timeout)
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
end
