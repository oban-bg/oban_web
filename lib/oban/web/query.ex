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
    Oban.cancel_all_jobs(name, only_ids(job_ids))

    :ok
  end

  @doc false
  def delete_jobs(%Config{} = conf, [_ | _] = job_ids) do
    Repo.delete_all(conf, only_ids(job_ids))

    :ok
  end

  @doc false
  def retry_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Oban.retry_all_jobs(name, only_ids(job_ids))

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
  def queue_state_counts(_conf, []), do: []

  def queue_state_counts(%Config{} = conf, [_ | _] = states) do
    query =
      Job
      |> where([j], j.state in ^states)
      |> group_by([j], [j.queue, j.state])
      |> select([j], {j.queue, j.state, count(j.id)})

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
