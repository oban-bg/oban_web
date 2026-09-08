defmodule Oban.Web.JobQuery do
  @moduledoc false

  use Oban.Web.Queryable

  import Ecto.Query
  import Oban.Web.QueryHelpers

  alias Oban.{Config, Job, Repo}
  alias Oban.Web.{Cache, Resolver}

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
    :meta,
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

  @states Map.new(Oban.Job.states(), &{to_string(&1), &1})

  @archive {"oban_jobs_archive", Job}
  @archive_states ~w(cancelled discarded completed)

  @history_limit 60

  defmacrop json_table(field) do
    quote do
      fragment("json_table(?, '$[*]' COLUMNS (value TEXT PATH '$'))", unquote(field))
    end
  end

  defmacrop json_unnest(field) do
    quote do
      fragment(
        """
        (SELECT value FROM json_array_elements_text(array_to_json(?)) AS t(value))
        """,
        unquote(field)
      )
    end
  end

  defmacrop chunk_sibling(field) do
    quote do
      fragment(
        "coalesce(?[array_length(?, 1)], '') LIKE 'chunk-%'",
        unquote(field),
        unquote(field)
      )
    end
  end

  # The key is inlined so the expression matches Pro's `(meta->>'key')` indexes.
  defmacrop meta_text(field, key) when is_binary(key) do
    quote do
      fragment(unquote("?->>'#{key}'"), unquote(field))
    end
  end

  defmacrop json_text(field, key) when is_binary(key) do
    quote do
      fragment(unquote("json_extract(?, '$.#{key}')"), unquote(field))
    end
  end

  defmacrop mysql_kv_table(field) do
    quote do
      fragment(
        """
        (SELECT jt.name AS `key`,
                json_extract(?, CONCAT('$.', jt.name)) AS `value`
        FROM json_table(json_keys(?), '$[*]' COLUMNS (name TEXT PATH '$')) AS jt)
        """,
        unquote(field),
        unquote(field)
      )
    end
  end

  defmacrop mysql_path_key(key, value) do
    quote do
      fragment(
        "CONCAT(?, (CASE json_type(?) WHEN 'OBJECT' THEN '.' ELSE ':' END))",
        unquote(key),
        unquote(value)
      )
    end
  end

  defmacrop postgres_path_key(key, value) do
    quote do
      fragment(
        "? || (CASE jsonb_typeof(?) WHEN 'object' THEN '.' ELSE ':' END)",
        unquote(key),
        unquote(value)
      )
    end
  end

  defmacrop sqlite_path_key(key, value) do
    quote do
      fragment(
        "? || (CASE json_type(json_quote(?)) WHEN 'object' THEN '.' ELSE ':' END)",
        unquote(key),
        unquote(value)
      )
    end
  end

  # MySQL raises an out of bounds error when subtracting from an UNSIGNED value returns a value
  # less than 0. There's no standard `greatest/max` function that can clamp to 0, so we use a case
  # statement instead.
  defmacrop subtract_unsigned(id, limit) do
    quote do
      fragment(
        "CASE WHEN ? > ? THEN ? - ? ELSE 1 END",
        unquote(id),
        unquote(limit),
        unquote(id),
        unquote(limit)
      )
    end
  end

  @suggest_priority [
    {"0", "critical", "priorities:0"},
    {"1", "urgent", "priorities:1"},
    {"2", "high", "priorities:2"},
    {"3", "medium-high", "priorities:3"},
    {"4", "medium", "priorities:4"},
    {"5", "medium-low", "priorities:5"},
    {"6", "low", "priorities:6"},
    {"7", "very-low", "priorities:7"},
    {"8", "minimal", "priorities:8"},
    {"9", "negligible", "priorities:9"}
  ]

  # Searching

  @impl Queryable
  def qualifiers do
    [
      args: [
        kind: :path,
        desc: "a key or value in args",
        example: "args.id:123",
        suggest: &suggest_args_vals/4,
        suggest_keys: &suggest_args_keys/3
      ],
      backfills: [desc: "backfill id", example: "backfills:0192a1b2-...", parse: :list],
      chains: [desc: "chain id", example: "chains:aB3d...", parse: :list],
      chunks: [desc: "chunk leader job id", example: "chunks:123", parse: :ints],
      ids: [desc: "one or more job ids", example: "ids:1,2,3", parse: :ints],
      meta: [
        kind: :path,
        desc: "a key or value in meta",
        example: "meta.batch_id:123",
        suggest: &suggest_meta_vals/4,
        suggest_keys: &suggest_meta_keys/3
      ],
      nodes: [desc: "host name", example: "nodes:machine@somehost", suggest: &suggest_nodes/3],
      priorities: [
        desc: "number from 0 to 9",
        example: "priorities:1",
        suggest: @suggest_priority,
        parse: :ints
      ],
      queues: [desc: "queue name", example: "queues:default", suggest: &suggest_queues/3],
      tags: [desc: "tag name", example: "tags:super,duper", suggest: &suggest_tags/3],
      workers: [
        desc: "worker module",
        example: "workers:MyApp.SomeWorker",
        suggest: &suggest_workers/3
      ],
      state: [hidden: true, parse: :string],
      archive: [hidden: true, parse: :string]
    ]
  end

  # Sources

  @doc """
  Whether params select the archive table rather than live jobs.
  """
  def archived?(%{archive: "true"}), do: true
  def archived?(_params), do: false

  @doc """
  The states a job may have in the archive, in sidebar order.
  """
  def archive_states, do: @archive_states

  defp source(opts) do
    if Keyword.get(opts, :archive, false), do: @archive, else: Job
  end

  defp with_source(opts, params), do: Keyword.put(opts, :archive, archived?(params))

  # Suggestions come from whichever table the page is showing, so hints match the visible jobs.
  def suggest(terms, conf, opts) do
    opts = with_source(opts, Keyword.get(opts, :params, %{}))

    Search.suggest(terms, qualifiers(), conf, opts)
  end

  defp suggest_args_keys(path, conf, opts), do: suggest_json_path(:args, path, conf, opts)

  defp suggest_meta_keys(path, conf, opts), do: suggest_json_path(:meta, path, conf, opts)

  defp suggest_args_vals(path, frag, conf, opts),
    do: suggest_json_vals(:args, path, frag, conf, opts)

  defp suggest_meta_vals(path, frag, conf, opts),
    do: suggest_json_vals(:meta, path, frag, conf, opts)

  defp suggest_json_path(field, term, conf, opts) do
    {frag, path} =
      term
      |> String.split(".")
      |> then(&List.pop_at(&1, length(&1) - 1))

    json_path = json_path(path)

    query = hint_limit_query(field, opts, conf)

    subquery =
      cond do
        Enum.empty?(path) ->
          select(query, [j], %{value: field(j, ^field)})

        is_mysql(conf) ->
          query
          |> select([j], %{value: fragment("json_extract(?, ?)", field(j, ^field), ^json_path)})
          |> where([j], mysql_extract_type(field(j, ^field), ^json_path) == "object")

        is_sqlite(conf) ->
          query
          |> select([j], %{value: fragment("?->?", field(j, ^field), ^json_path)})
          |> where([j], sqlite_extract_type(field(j, ^field), ^json_path) == "object")

        true ->
          query
          |> select([j], %{value: fragment("?#>?", field(j, ^field), ^path)})
          |> where([j], postgres_extract_type(field(j, ^field), ^path) == "object")
      end

    query =
      cond do
        is_mysql(conf) ->
          subquery
          |> subquery()
          |> join(:inner_lateral, [o], x in mysql_kv_table(o.value), on: true)
          |> select([_, x], mysql_path_key(x.key, x.value))
          |> distinct(true)

        is_sqlite(conf) ->
          subquery
          |> subquery()
          |> join(:inner, [o], x in fragment("json_each(?)", o.value), on: true)
          |> select([_, x], sqlite_path_key(x.key, x.value))
          |> distinct(true)

        true ->
          subquery
          |> subquery()
          |> join(:inner_lateral, [o], x in fragment("jsonb_each(?)", o.value), on: true)
          |> select([_, x], postgres_path_key(x.key, x.value))
          |> distinct(true)
      end

    {field, :keys, path}
    |> cache_query(query, conf, opts)
    |> Kernel.--(~w(return: storage: size: safe_decode:))
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_json_vals(_field, "", _frag, _conf, _opts), do: []

  defp suggest_json_vals(field, path, frag, conf, opts) do
    json_path = json_path(path)
    scalars = ~w(boolean double integer number real string text)

    query =
      field
      |> hint_limit_query(opts, conf)
      |> distinct(true)

    query =
      cond do
        is_mysql(conf) ->
          query
          |> select([j], fragment("json_extract(?, ?)", field(j, ^field), ^json_path))
          |> where([j], mysql_extract_type(field(j, ^field), ^json_path) in ^scalars)

        is_sqlite(conf) ->
          query
          |> select([j], fragment("json_extract(?, ?)", field(j, ^field), ^json_path))
          |> where([j], sqlite_extract_type(field(j, ^field), ^json_path) in ^scalars)

        true ->
          path = String.split(path, ".")

          query
          |> select([j], fragment("?#>?", field(j, ^field), ^path))
          |> where([j], postgres_extract_type(field(j, ^field), ^path) in ^scalars)
      end

    {field, :vals, path}
    |> cache_query(query, conf, opts)
    |> Enum.map(&String.slice(to_string(&1), 0..90))
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_nodes(frag, conf, opts) do
    query =
      :nodes
      |> hint_limit_query(opts, conf)
      |> distinct(true)
      |> where([j], j.state not in ~w(available scheduled))

    query =
      if is_sqlite(conf) or is_mysql(conf) do
        select(query, [j], fragment("?->>'$[0]'", j.attempted_by))
      else
        select(query, [j], fragment("?[1]", j.attempted_by))
      end

    :nodes
    |> cache_query(query, conf, opts)
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_queues(frag, conf, opts) do
    query =
      :queues
      |> hint_limit_query(opts, conf)
      |> select([j], j.queue)
      |> distinct(true)

    :queues
    |> cache_query(query, conf, opts)
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_tags(frag, conf, opts) do
    query = hint_limit_query(:tags, opts, conf)

    query =
      cond do
        is_sqlite(conf) ->
          join(query, :inner, [j], x in fragment("json_each(?)", j.tags), on: true)

        is_mysql(conf) ->
          join(query, :inner, [j], x in json_table(j.tags), on: true)

        true ->
          join(query, :inner_lateral, [j], x in json_unnest(j.tags), on: true)
      end

    query =
      query
      |> select([_, x], x.value)
      |> distinct(true)

    :tags
    |> cache_query(query, conf, opts)
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_workers(frag, conf, opts) do
    query =
      :workers
      |> hint_limit_query(opts, conf)
      |> select([j], j.worker)
      |> distinct(true)

    :workers
    |> cache_query(query, conf, opts)
    |> Search.restrict_suggestions(frag)
  end

  defp cache_query(key, query, conf, opts) do
    key = if Keyword.get(opts, :archive, false), do: {:archive, key}, else: key

    Cache.fetch(key, fn -> Repo.all(conf, query) end)
  end

  # Queries

  def all_jobs(params, conf, opts \\ []) do
    params = params_with_defaults(params)
    conditions = conditions(params, conf)
    opts = with_source(opts, params)

    query =
      params.state
      |> jobs_limit_query(opts, conf)
      |> select(^@list_fields)
      |> where(^conditions)
      |> order(params.sort_by, params.state, params.sort_dir)
      |> limit(^params.limit)

    Repo.all(conf, query)
  end

  def all_job_ids(params, conf, opts \\ []) do
    params = params_with_defaults(params)
    conditions = conditions(params, conf)
    limit = bulk_action_limit(params.state, opts)
    opts = with_source(opts, params)

    query =
      params.state
      |> jobs_limit_query(opts, conf)
      |> select([j], j.id)
      |> where(^conditions)
      |> order(params.sort_by, params.state, params.sort_dir)
      |> limit(^limit)

    Repo.all(conf, query)
  end

  defp conditions(params, conf) do
    params
    |> Enum.reduce(true, &filter(&1, &2, conf))
    |> fold_chunk_siblings(params, conf)
  end

  # A running chunk is one unit of work, so the executing list shows only its leader. Siblings
  # stay visible when a search asks for jobs by id or by chunk, and in every other state, where
  # each job has an outcome of its own.
  defp fold_chunk_siblings(conditions, _params, conf) when is_mysql(conf) or is_sqlite(conf) do
    conditions
  end

  defp fold_chunk_siblings(conditions, %{state: "executing"} = params, _conf) do
    if Map.has_key?(params, :ids) or Map.has_key?(params, :chunks) do
      conditions
    else
      dynamic([j], ^conditions and not chunk_sibling(j.attempted_by))
    end
  end

  defp fold_chunk_siblings(conditions, _params, _conf), do: conditions

  defp params_with_defaults(params) do
    @defaults
    |> Map.merge(params)
    |> Map.update!(:sort_by, &maybe_atomize/1)
    |> Map.update!(:sort_dir, &maybe_atomize/1)
  end

  defp jobs_limit_query(state, opts, conf) do
    @states
    |> Map.fetch!(state)
    |> limit_query(:jobs_query_limit, opts, conf)
  end

  defp hint_limit_query(qual, opts, conf) do
    limit_query(qual, :hint_query_limit, opts, conf)
  end

  defp bulk_action_limit(state, opts) do
    Resolver.call_with_fallback(opts[:resolver], :bulk_action_limit, [state])
  end

  defp limit_query(value, fun, opts, conf) do
    source = source(opts)

    case Resolver.call_with_fallback(opts[:resolver], fun, [value]) do
      :infinity ->
        source

      limit ->
        last_id =
          source
          |> select([j], type(subtract_unsigned(j.id, ^limit), :integer))
          |> order_by(desc: :id)
          |> limit(1)
          |> then(&Repo.one(conf, &1))

        where(source, [j], j.id >= ^(last_id || 0))
    end
  end

  def refresh_job(conf, job, opts \\ [])

  def refresh_job(%Config{} = conf, %Job{id: job_id} = job, opts) do
    query =
      opts
      |> source()
      |> where(id: ^job_id)
      |> select([j], map(j, ^@refresh_fields))

    case Repo.all(conf, query) do
      [] ->
        nil

      [new_job] ->
        Enum.reduce(new_job, job, fn {key, val}, acc -> %{acc | key => val} end)
    end
  end

  def refresh_job(%Config{} = conf, job_id, opts) when is_binary(job_id) or is_integer(job_id) do
    Repo.get(conf, source(opts), job_id)
  end

  def refresh_job(_conf, nil, _opts), do: nil

  @history_states ~w(executing completed cancelled discarded)

  def job_history(job, conf, opts \\ []) do
    worker = Map.get(job.meta, "worker", job.worker)

    query =
      opts
      |> source()
      |> where([j], j.worker == ^worker)
      |> where([j], j.id <= ^job.id)
      |> where([j], j.state in @history_states)
      |> order_by([j], desc: j.id)
      |> limit(@history_limit)
      |> select([j], %{
        id: j.id,
        state: j.state,
        scheduled_at: j.scheduled_at,
        attempted_at: j.attempted_at,
        completed_at: j.completed_at,
        cancelled_at: j.cancelled_at,
        discarded_at: j.discarded_at
      })

    conf
    |> Repo.all(query)
    |> Enum.reverse()
  end

  @doc """
  Count the jobs in a leader's chunk by state, including the leader itself.

  Members share the leader's partition `chunk_id`, which narrows the scan to the partition
  through the meta index before matching the `chunk-<id>` marker in `attempted_by`.
  """
  def chunk_counts(conf, job, opts \\ [])

  def chunk_counts(conf, _job, _opts) when is_mysql(conf) or is_sqlite(conf), do: %{}

  def chunk_counts(%Config{} = conf, %Job{id: id, meta: %{"chunk_id" => chunk_id}} = job, opts) do
    query =
      opts
      |> source()
      |> where([j], fragment("? @> ?", j.meta, ^%{chunk_id: chunk_id}))
      |> where([j], fragment("? @> ?", j.attempted_by, ^["chunk-#{id}"]))
      |> group_by([j], j.state)
      |> select([j], {j.state, count(j.id)})

    conf
    |> Repo.all(query)
    |> Map.new()
    |> Map.update(job.state, 1, &(&1 + 1))
  end

  def chunk_counts(_conf, _job, _opts), do: %{}

  @doc """
  The jobs immediately before and after a job in its chain or backfill.

  Chains and backfills run in insertion order, so the neighbors are the nearest ids on either side
  that share the job's `chain_id` or `backfill_id`. Either side is nil at the ends of the sequence.
  """
  @spec neighbors(Config.t(), Job.t(), :chain | :backfill, keyword()) :: %{
          prev: Job.t() | nil,
          next: Job.t() | nil
        }
  def neighbors(conf, job, kind, opts \\ [])

  def neighbors(conf, _job, _kind, _opts) when is_mysql(conf) or is_sqlite(conf),
    do: %{prev: nil, next: nil}

  def neighbors(%Config{} = conf, %Job{id: id} = job, kind, opts) do
    case sequence_query(job, kind, source(opts)) do
      nil ->
        %{prev: nil, next: nil}

      query ->
        prev_query = query |> where([j], j.id < ^id) |> order_by(desc: :id) |> limit(1)
        next_query = query |> where([j], j.id > ^id) |> order_by(asc: :id) |> limit(1)

        %{prev: Repo.one(conf, prev_query), next: Repo.one(conf, next_query)}
    end
  end

  # Backfill lookups hit Pro's `(meta->>'backfill_id', state)` index. The chain index is partial
  # and excludes completed jobs, so chains use containment through the meta index instead.
  defp sequence_query(%Job{meta: %{"chain_id" => chain_id}}, :chain, source)
       when is_binary(chain_id) do
    where(source, [j], fragment("? @> ?", j.meta, ^%{chain_id: chain_id}))
  end

  defp sequence_query(%Job{meta: %{"backfill_id" => backfill_id}}, :backfill, source)
       when is_binary(backfill_id) do
    where(source, [j], meta_text(j.meta, "backfill_id") == ^backfill_id)
  end

  defp sequence_query(_job, _kind, _source), do: nil

  def cancel_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Oban.cancel_all_jobs(name, only_ids(job_ids))

    :ok
  end

  def cancel_jobs(_conf, _ids), do: :ok

  def delete_jobs(conf, job_ids, opts \\ [])

  def delete_jobs(%Config{} = conf, [_ | _] = job_ids, archive: true) do
    Repo.delete_all(conf, where(@archive, [j], j.id in ^job_ids))

    :ok
  end

  def delete_jobs(%Config{name: name}, [_ | _] = job_ids, _opts) do
    Oban.delete_all_jobs(name, only_ids(job_ids))

    :ok
  end

  def delete_jobs(_conf, _ids, _opts), do: :ok

  def retry_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Oban.retry_all_jobs(name, only_ids(job_ids))

    :ok
  end

  def retry_jobs(_conf, _ids), do: :ok

  # Filter Helpers

  defp json_path(path) when is_list(path), do: Enum.join(["$" | path], ".")
  defp json_path(path) when is_binary(path), do: "$." <> path

  defp only_ids(job_ids), do: where(Job, [j], j.id in ^job_ids)

  defp maybe_atomize(val) when is_binary(val), do: String.to_existing_atom(val)
  defp maybe_atomize(val), do: val

  defp filter({:args, [path, term]}, condition, conf) when is_sqlite(conf) or is_mysql(conf) do
    json_path = json_path(path)
    cast_term = cast_val(term)

    dynamic([j], ^condition and fragment("json_extract(?, ?)", j.args, ^json_path) == ^cast_term)
  end

  defp filter({:args, [path, term]}, condition, _conf) do
    dynamic([j], ^condition and fragment("? @> ?", j.args, ^gen_map(path, term)))
  end

  defp filter({:backfills, ids}, condition, conf) when is_mysql(conf) or is_sqlite(conf) do
    dynamic([j], ^condition and json_text(j.meta, "backfill_id") in ^ids)
  end

  defp filter({:backfills, ids}, condition, _conf) do
    dynamic([j], ^condition and meta_text(j.meta, "backfill_id") in ^ids)
  end

  defp filter({:chains, ids}, condition, conf) when is_mysql(conf) or is_sqlite(conf) do
    dynamic([j], ^condition and json_text(j.meta, "chain_id") in ^ids)
  end

  defp filter({:chains, ids}, condition, _conf) do
    dynamic([j], ^condition and meta_text(j.meta, "chain_id") in ^ids)
  end

  defp filter({:chunks, ids}, condition, conf) when is_mysql(conf) or is_sqlite(conf) do
    dynamic([j], ^condition and j.id in ^ids)
  end

  defp filter({:chunks, ids}, condition, _conf) do
    markers = Enum.map(ids, &"chunk-#{&1}")

    dynamic([j], ^condition and (j.id in ^ids or fragment("? && ?", j.attempted_by, ^markers)))
  end

  defp filter({:ids, ids}, condition, _conf) do
    dynamic([j], ^condition and j.id in ^ids)
  end

  defp filter({:meta, [path, term]}, condition, conf) when is_sqlite(conf) or is_mysql(conf) do
    json_path = json_path(path)
    cast_term = cast_val(term)

    dynamic([j], ^condition and fragment("json_extract(?, ?)", j.meta, ^json_path) == ^cast_term)
  end

  defp filter({:meta, [path, term]}, condition, _conf) do
    dynamic([j], ^condition and fragment("? @> ?", j.meta, ^gen_map(path, term)))
  end

  defp filter({:nodes, nodes}, condition, conf) when is_sqlite(conf) or is_mysql(conf) do
    dynamic([j], ^condition and fragment("?->>'$[0]'", j.attempted_by) in ^nodes)
  end

  defp filter({:nodes, nodes}, condition, _conf) do
    dynamic([j], ^condition and fragment("?[1]", j.attempted_by) in ^nodes)
  end

  defp filter({:queues, queues}, condition, _conf) do
    dynamic([j], ^condition and j.queue in ^queues)
  end

  defp filter({:priorities, priorities}, condition, _conf) do
    dynamic([j], ^condition and j.priority in ^priorities)
  end

  defp filter({:state, state}, condition, _conf) do
    dynamic([j], ^condition and j.state == ^state)
  end

  defp filter({:tags, tags}, condition, conf) when is_mysql(conf) do
    dynamic([j], ^condition and fragment("json_overlaps(?, ?)", j.tags, ^tags))
  end

  defp filter({:tags, tags}, condition, conf) when is_sqlite(conf) do
    dynamic([j], ^condition and sqlite_contains_any(j.tags, tags))
  end

  defp filter({:tags, tags}, condition, _conf) do
    dynamic([j], ^condition and fragment("? && ?", j.tags, ^tags))
  end

  defp filter({:workers, workers}, condition, _conf) do
    dynamic([j], ^condition and j.worker in ^workers)
  end

  defp filter(_, condition, _conf), do: condition

  defp gen_map(path, val) do
    gen_map(path, cast_val(val), {[], %{}})
  end

  defp gen_map([], _val, {_path, acc}), do: acc
  defp gen_map([key], val, {path, acc}), do: put_in(acc, path ++ [key], val)

  defp gen_map([key | tail], val, {path, acc}) do
    gen_map(tail, val, {path ++ [key], put_in(acc, path ++ [key], %{})})
  end

  defp cast_val("true"), do: true
  defp cast_val("false"), do: false

  defp cast_val(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> String.trim(val, "\"")
    end
  end

  # Ordering Helpers

  defp order(query, :attempt, _state, dir) do
    order_by(query, [j], {^dir, j.attempt})
  end

  defp order(query, :queue, _state, dir) do
    order_by(query, [j], {^dir, j.queue})
  end

  defp order(query, :time, state, dir)
       when state in ~w(suspended available retryable scheduled) do
    order_by(query, [j], {^dir, j.scheduled_at})
  end

  defp order(query, :time, "cancelled", dir) do
    order_by(query, [j], {^flip_dir(dir), j.cancelled_at})
  end

  defp order(query, :time, "completed", dir) do
    order_by(query, [j], {^flip_dir(dir), j.completed_at})
  end

  defp order(query, :time, "executing", dir) do
    order_by(query, [j], {^dir, j.attempted_at})
  end

  defp order(query, :time, "discarded", dir) do
    order_by(query, [j], {^flip_dir(dir), j.discarded_at})
  end

  defp order(query, :worker, _state, dir) do
    order_by(query, [j], {^dir, j.worker})
  end

  defp flip_dir(:asc), do: :desc
  defp flip_dir(:desc), do: :asc
end
