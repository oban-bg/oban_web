defmodule Oban.Web.Query do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Config, Job, Repo}

  @defaults %{
    limit: 30,
    sort_by: "time",
    sort_dir: "asc",
    state: "executing"
  }

  @list_fields [
    :id,
    :args,
    :attempt,
    :attempted_by,
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

  defmacrop json_search(column, terms) do
    quote do
      fragment(
        """
        jsonb_to_tsvector('english', ? - 'recorded', '["all"]') @@ websearch_to_tsquery(?)
        """,
        unquote(column),
        unquote(terms)
      )
    end
  end

  defmacrop json_path_search(column, path, terms) do
    quote do
      fragment(
        """
        jsonb_to_tsvector('english', ? #> ?, '["all"]') @@ websearch_to_tsquery(?)
        """,
        unquote(column),
        unquote(path),
        unquote(terms)
      )
    end
  end

  @doc false
  def all_jobs(%Config{} = conf, %{} = args) do
    args =
      @defaults
      |> Map.merge(args)
      |> Map.update!(:sort_by, &maybe_atomize/1)
      |> Map.update!(:sort_dir, &maybe_atomize/1)

    conditions = Enum.reduce(args, true, &filter/2)

    query =
      Job
      |> where(^conditions)
      |> order(args.sort_by, args.state, args.sort_dir)
      |> limit(^args.limit)
      |> select(^@list_fields)

    Repo.all(conf, query)
  end

  defp maybe_atomize(val) when is_binary(val), do: String.to_existing_atom(val)
  defp maybe_atomize(val), do: val

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
        Enum.reduce(new_job, job, fn {key, val}, acc -> %{acc | key => val} end)
    end
  end

  def refresh_job(%Config{} = conf, job_id) when is_binary(job_id) or is_integer(job_id) do
    Repo.get(conf, Job, job_id)
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

  # Filter Helpers

  defp only_ids(job_ids), do: where(Job, [j], j.id in ^job_ids)

  defp filter({:args, [parts, terms]}, condition) do
    dynamic([j], ^condition and json_path_search(j.args, ^parts, ^terms))
  end

  defp filter({:args, terms}, condition) do
    dynamic([j], ^condition and json_search(j.args, ^terms))
  end

  defp filter({:meta, [parts, terms]}, condition) do
    dynamic([j], ^condition and json_path_search(j.meta, ^parts, ^terms))
  end

  defp filter({:meta, terms}, condition) do
    dynamic([j], ^condition and json_search(j.meta, ^terms))
  end

  defp filter({:nodes, nodes}, condition) do
    dynamic([j], ^condition and fragment("?[1]", j.attempted_by) in ^nodes)
  end

  defp filter({:queues, queues}, condition) do
    dynamic([j], ^condition and j.queue in ^queues)
  end

  defp filter({:priorities, priorities}, condition) do
    dynamic([j], ^condition and j.priority in ^priorities)
  end

  defp filter({:state, state}, condition) do
    dynamic([j], ^condition and j.state == ^state)
  end

  defp filter({:tags, tags}, condition) do
    dynamic([j], ^condition and fragment("? && ?", j.tags, ^tags))
  end

  defp filter({:workers, workers}, condition) do
    dynamic([j], ^condition and j.worker in ^workers)
  end

  defp filter(_, condition), do: condition

  # Ordering Helpers

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
end
