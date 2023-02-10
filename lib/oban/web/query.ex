defmodule Oban.Web.Query do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Config, Job, Repo, Web.Search}

  @defaults %{
    limit: 30,
    sort_by: "time",
    sort_dir: "asc",
    state: "executing"
  }

  @minimum_pg_for_search 110_000

  @list_fields [
    :id,
    :args,
    :attempt,
    :worker,
    :queue,
    :max_attempts,
    :state,
    :inserted_at,
    :attempted_at,
    :cancelled_at,
    :completed_at,
    :discarded_at,
    :scheduled_at
  ]

  @refresh_fields [
    :attempt,
    :errors,
    :meta,
    :state,
    :attempted_at,
    :cancelled_at,
    :completed_at,
    :discarded_at,
    :scheduled_at
  ]

  @doc false
  def all_jobs(%Config{} = conf, %{} = args) do
    maybe_atomize = fn
      val when is_binary(val) -> String.to_existing_atom(val)
      val when is_atom(val) -> val
    end

    args =
      @defaults
      |> Map.merge(args)
      |> Map.update!(:sort_by, maybe_atomize)
      |> Map.update!(:sort_dir, maybe_atomize)

    query =
      args
      |> Enum.reduce(Job, &filter(&1, &2, conf))
      |> order(args[:sort_by], args[:state], args[:sort_dir])
      |> limit(^args[:limit])
      |> select(^@list_fields)

    conf
    |> Repo.all(query)
    |> Enum.map(&relativize_timestamps/1)
  end

  @doc false
  def refresh_job(_conf, nil), do: nil

  def refresh_job(%Config{} = conf, %Job{id: job_id} = job) do
    query =
      Job
      |> where(id: ^job_id)
      |> select([j], map(j, ^@refresh_fields))

    case Repo.all(conf, query) do
      [] ->
        nil

      [new_job] ->
        new_job
        |> Enum.reduce(job, fn {key, val}, acc -> %{acc | key => val} end)
        |> relativize_timestamps()
    end
  end

  def refresh_job(%Config{} = conf, job_id) when is_binary(job_id) or is_integer(job_id) do
    case Repo.all(conf, where(Job, id: ^job_id)) do
      [] -> nil
      [job] -> relativize_timestamps(job)
    end
  end

  @doc false
  def cancel_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Oban.cancel_all_jobs(name, only_ids(job_ids))

    :ok
  end

  @doc false
  def delete_jobs(%Config{} = conf, [_ | _] = job_ids) do
    Repo.delete_all(conf, only_ids(job_ids))

    :ok
  end

  @doc false
  def retry_jobs(%Config{} = conf, [_ | _] = job_ids) do
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
  def queue_state_counts(_conf, []), do: []

  def queue_state_counts(%Config{} = conf, [_ | _] = states) do
    query =
      Job
      |> where([j], j.state in ^states)
      |> group_by([j], [j.queue, j.state])
      |> select([j], {j.queue, j.state, count(j.id)})

    Repo.all(conf, query, timeout: :timer.seconds(20))
  end

  # Helpers

  defp only_ids(job_ids), do: where(Job, [j], j.id in ^job_ids)

  defp filter({:nodes, named_nodes}, query, _conf) do
    nodes =
      for name_node <- named_nodes do
        name_node
        |> String.downcase()
        |> String.split("/")
        |> List.first()
      end

    where(query, [j], fragment("lower(?[1])", j.attempted_by) in ^nodes)
  end

  defp filter({:queues, queues}, query, _conf), do: where(query, [j], j.queue in ^queues)
  defp filter({:state, state}, query, _conf), do: where(query, state: ^state)

  defp filter({:terms, terms}, query, conf) when byte_size(terms) > 0 do
    if pg_version(conf) >= @minimum_pg_for_search do
      Search.build(query, terms)
    else
      where(query, [j], ilike(j.worker, ^"%#{terms}%"))
    end
  end

  defp filter(_, query, _conf), do: query

  defp order(query, :attempt, _state, dir) do
    order_by(query, [j], {^dir, j.attempt})
  end

  defp order(query, :queue, _state, dir) do
    order_by(query, [j], {^dir, j.queue})
  end

  defp order(query, :time, state, dir) when state in ~w(available retryable scheduled) do
    order_by(query, [j], {^dir, j.scheduled_at})
  end

  defp order(query, :time, "cancelled", dir) do
    order_by(query, [j], {^dir, j.cancelled_at})
  end

  defp order(query, :time, "completed", dir) do
    order_by(query, [j], {^dir, j.completed_at})
  end

  defp order(query, :time, "executing", dir) do
    order_by(query, [j], {^dir, j.attempted_at})
  end

  defp order(query, :time, "discarded", dir) do
    order_by(query, [j], {^dir, j.discarded_at})
  end

  defp order(query, :worker, _state, dir) do
    order_by(query, [j], {^dir, j.worker})
  end

  # Once a job is attempted or scheduled the timestamp doesn't change. That prevents LiveView from
  # re-rendering the relative time, which makes it look like the view is broken. To work around
  # this issue we inject relative values to trigger change tracking.
  defp relativize_timestamps(job, now \\ NaiveDateTime.utc_now()) do
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
