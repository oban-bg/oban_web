defmodule Oban.Web.JobQuery do
  @moduledoc false

  import Ecto.Query

  alias Oban.{Config, Job, Repo}
  alias Oban.Web.{Cache, Resolver, Search}

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

  # Split terms using a positive lookahead that skips splitting within double quotes
  @split_pattern ~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/

  defguardp is_mysql(conf) when conf.engine == Oban.Engines.Dolphin

  defguardp is_sqlite(conf) when conf.engine == Oban.Engines.Lite

  defmacrop json_table(field) do
    quote do
      fragment("json_table(?, '$[*]' COLUMNS (value TEXT PATH '$'))", unquote(field))
    end
  end

  defmacrop json_unnest(field) do
    quote do
      fragment("json_array_elements_text(array_to_json(?))", unquote(field))
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

  defmacrop mysql_extract_type(field, path) do
    quote do
      fragment("lower(json_type(json_extract(?, ?)))", unquote(field), unquote(path))
    end
  end

  defmacrop sqlite_extract_type(field, path) do
    quote do
      fragment("json_type(?->?)", unquote(field), unquote(path))
    end
  end

  defmacrop postgres_extract_type(field, path) do
    quote do
      fragment("jsonb_typeof(?#>?)", unquote(field), unquote(path))
    end
  end

  defmacrop sqlite_contains_any(column, list) do
    quote do
      fragment(
        """
        exists (
          select 1
          from json_each(?) as t1, json_each(?) as t2
          where t1.value = t2.value
        )
        """,
        unquote(column),
        ^Oban.JSON.encode!(unquote(list))
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

  def parse(terms) when is_binary(terms) do
    Search.parse(terms, &parse_term/1)
  end

  @suggest_qualifier [
    {"args.", "a key or value in args", "args.id:123"},
    {"ids:", "one or more job ids", "ids:1,2,3"},
    {"meta.", "a key or value in meta", "meta.batch_id:123"},
    {"nodes:", "host name", "nodes:machine@somehost"},
    {"priorities:", "number from 0 to 9", "priorities:1"},
    {"queues:", "queue name", "queues:default"},
    {"tags:", "tag name", "tags:super,duper"},
    {"workers:", "worker module", "workers:MyApp.SomeWorker"}
  ]

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

  @known_qualifiers for {qualifier, _, _} <- @suggest_qualifier, into: MapSet.new(), do: qualifier

  def filterable, do: ~w(args ids meta nodes priorities queues tags workers)a

  def suggest(terms, conf, opts \\ []) do
    terms
    |> String.split(@split_pattern)
    |> List.last()
    |> to_string()
    |> case do
      "" ->
        @suggest_qualifier

      last ->
        case String.split(last, ":", parts: 2) do
          ["args." <> path, frag] -> suggest_json_vals(:args, path, frag, conf, opts)
          ["meta." <> path, frag] -> suggest_json_vals(:meta, path, frag, conf, opts)
          ["nodes", frag] -> suggest_nodes(frag, conf, opts)
          ["queues", frag] -> suggest_queues(frag, conf, opts)
          ["priorities", frag] -> suggest_static(@suggest_priority, frag)
          ["tags", frag] -> suggest_tags(frag, conf, opts)
          ["workers", frag] -> suggest_workers(frag, conf, opts)
          ["args." <> path] -> suggest_json_path(:args, path, conf, opts)
          ["meta." <> path] -> suggest_json_path(:meta, path, conf, opts)
          [frag] -> suggest_static(@suggest_qualifier, frag)
          _ -> []
        end
    end
  end

  defp suggest_static(possibilities, fragment) do
    for {field, _, _} = suggest <- possibilities,
        String.starts_with?(field, fragment),
        do: suggest
  end

  defp suggest_json_path(field, term, conf, opts) do
    {frag, path} =
      term
      |> String.split(".")
      |> then(&List.pop_at(&1, length(&1) - 1))

    json_path = json_path(path)

    query = hint_limit_query(field, opts)

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
    |> cache_query(query, conf)
    |> Kernel.--(["return:"])
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_json_vals(_field, "", _frag, _conf, _opts), do: []

  defp suggest_json_vals(field, path, frag, conf, opts) do
    json_path = json_path(path)
    scalars = ~w(boolean double integer number real string text)

    query =
      field
      |> hint_limit_query(opts)
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
    |> cache_query(query, conf)
    |> Enum.map(&String.slice(to_string(&1), 0..90))
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_nodes(frag, conf, opts) do
    query =
      :nodes
      |> hint_limit_query(opts)
      |> distinct(true)
      |> where([j], j.state not in ~w(available scheduled))

    query =
      if is_sqlite(conf) or is_mysql(conf) do
        select(query, [j], fragment("?->>'$[0]'", j.attempted_by))
      else
        select(query, [j], fragment("?[1]", j.attempted_by))
      end

    :nodes
    |> cache_query(query, conf)
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_queues(frag, conf, opts) do
    query =
      :queues
      |> hint_limit_query(opts)
      |> select([j], j.queue)
      |> distinct(true)

    :queues
    |> cache_query(query, conf)
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_tags(frag, conf, opts) do
    query = hint_limit_query(:tags, opts)

    query =
      cond do
        is_sqlite(conf) ->
          join(query, :inner, [j], x in fragment("json_each(?)", j.tags), on: true)

        is_mysql(conf) ->
          join(query, :inner, [j], x in json_table(j.tags), on: true)

        true ->
          join(query, :inner, [j], x in json_unnest(j.tags), on: true)
      end

    query =
      query
      |> select([_, x], x.value)
      |> distinct(true)

    :tags
    |> cache_query(query, conf)
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_workers(frag, conf, opts) do
    query =
      :workers
      |> hint_limit_query(opts)
      |> select([j], j.worker)
      |> distinct(true)

    :workers
    |> cache_query(query, conf)
    |> Search.restrict_suggestions(frag)
  end

  defp cache_query(key, query, conf) do
    Cache.fetch(key, fn -> Repo.all(conf, query) end)
  end

  def append(terms, choice) do
    Search.append(terms, choice, @known_qualifiers)
  end

  def complete(terms, conf) do
    case suggest(terms, conf) do
      [] ->
        terms

      [{match, _, _} | _] ->
        append(terms, match)
    end
  end

  # Queries

  def all_jobs(params, conf, opts \\ []) do
    params = params_with_defaults(params)
    conditions = Enum.reduce(params, true, &filter(&1, &2, conf))

    query =
      params.state
      |> jobs_limit_query(opts)
      |> select(^@list_fields)
      |> where(^conditions)
      |> order(params.sort_by, params.state, params.sort_dir)
      |> limit(^params.limit)

    Repo.all(conf, query)
  end

  def all_job_ids(params, conf, opts \\ []) do
    params = params_with_defaults(params)
    conditions = Enum.reduce(params, true, &filter(&1, &2, conf))
    limit = bulk_action_limit(params.state, opts)

    query =
      params.state
      |> jobs_limit_query(opts)
      |> select([j], j.id)
      |> where(^conditions)
      |> order(params.sort_by, params.state, params.sort_dir)
      |> limit(^limit)

    Repo.all(conf, query)
  end

  defp params_with_defaults(params) do
    @defaults
    |> Map.merge(params)
    |> Map.update!(:sort_by, &maybe_atomize/1)
    |> Map.update!(:sort_dir, &maybe_atomize/1)
  end

  defp jobs_limit_query(state, opts) do
    @states
    |> Map.fetch!(state)
    |> limit_query(:jobs_query_limit, opts)
  end

  defp hint_limit_query(qual, opts) do
    limit_query(qual, :hint_query_limit, opts)
  end

  defp bulk_action_limit(state, opts) do
    Resolver.call_with_fallback(opts[:resolver], :bulk_action_limit, [state])
  end

  defp limit_query(value, fun, opts) do
    case Resolver.call_with_fallback(opts[:resolver], fun, [value]) do
      :infinity ->
        Job

      limit ->
        sublimit =
          Job
          |> select([j], subtract_unsigned(j.id, ^limit))
          |> order_by(desc: :id)
          |> limit(1)

        where(Job, [j], j.id >= subquery(sublimit))
    end
  end

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

  def refresh_job(_conf, nil), do: nil

  def cancel_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Oban.cancel_all_jobs(name, only_ids(job_ids))

    :ok
  end

  def cancel_jobs(_conf, _ids), do: :ok

  def delete_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Oban.delete_all_jobs(name, only_ids(job_ids))

    :ok
  end

  def delete_jobs(_conf, _ids), do: :ok

  def retry_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Oban.retry_all_jobs(name, only_ids(job_ids))

    :ok
  end

  def retry_jobs(_conf, _ids), do: :ok

  # Parsing Helpers

  defp parse_term("args:" <> terms) do
    {:args, String.trim(terms)}
  end

  defp parse_term("args." <> path_and_term) do
    parse_path(:args, path_and_term)
  end

  defp parse_term("ids:" <> ids) do
    parse_ints(:ids, ids)
  end

  defp parse_term("meta:" <> terms) do
    {:meta, String.trim(terms)}
  end

  defp parse_term("meta." <> path_and_term) do
    parse_path(:meta, path_and_term)
  end

  defp parse_term("nodes:" <> nodes) do
    {:nodes, String.split(nodes, ",")}
  end

  defp parse_term("priorities:" <> priorities) when byte_size(priorities) > 0 do
    parse_ints(:priorities, priorities)
  end

  defp parse_term("queues:" <> queues) do
    {:queues, String.split(queues, ",")}
  end

  defp parse_term("state:" <> states) do
    {:state, String.split(states, ",")}
  end

  defp parse_term("tags:" <> tags) do
    {:tags, String.split(tags, ",")}
  end

  defp parse_term("workers:" <> workers) do
    {:workers, String.split(workers, ",")}
  end

  defp parse_term(_term), do: {:none, ""}

  defp parse_ints(field, value) do
    {field,
     value
     |> String.split(",")
     |> Enum.map(&String.to_integer/1)}
  end

  defp parse_path(field, path_and_term) do
    case String.split(path_and_term, ":", parts: 2) do
      [path, term] ->
        {field, [String.split(path, "."), term]}

      [path] ->
        {field, [String.split(path, "."), ""]}
    end
  end

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

  defp order(query, :time, state, dir) when state in ~w(available retryable scheduled) do
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
