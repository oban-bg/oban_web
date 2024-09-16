defmodule Oban.Web.Query do
  @moduledoc false

  import Ecto.Query

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

  # Split terms using a positive lookahead that skips splitting within double quotes
  @split_pattern ~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/
  @ignored_chars ~w(; / \ ` ' = * ! ? # $ & + ^ | ~ < > ( \) { } [ ])

  defmacrop path_key(key, value) do
    quote do
      fragment(
        """
        case jsonb_typeof(?)
        when 'object' then ? || '.'
        else ? || ':'
        end
        """,
        unquote(value),
        unquote(key),
        unquote(key)
      )
    end
  end

  @doc """
  Parse a string of qualifiers and values into structured search terms.
  """
  def parse(terms) when is_binary(terms) do
    terms
    |> String.split(@split_pattern)
    |> Map.new(fn term ->
      term
      |> String.replace(@ignored_chars, "")
      |> parse_term()
    end)
  end

  @doc """
  Prepare parsed params for URI encoding.
  """
  def encode_params(params) do
    for {key, val} <- params, val != nil, val != "" do
      case val do
        [path, frag] when is_list(path) ->
          {key, Enum.join(path, ",") <> "++" <> frag}

        [_ | _] ->
          {key, Enum.join(val, ",")}

        _ ->
          {key, val}
      end
    end
  end

  def decode_params(params) do
    Map.new(params, fn
      {"limit", val} ->
        {:limit, String.to_integer(val)}

      {key, val} when key in ~w(args meta) ->
        val =
          val
          |> String.split("++")
          |> List.update_at(0, &String.split(&1, ","))

        {String.to_existing_atom(key), val}

      {key, val} when key in ~w(ids nodes priorities queues tags workers) ->
        {String.to_existing_atom(key), String.split(val, ",")}

      {key, val} ->
        {String.to_existing_atom(key), val}
    end)
  end

  @suggest_limit 10
  @suggest_threshold 0.5

  @suggest_qualifier [
    {"args.", "a key or value in args", "args.id:123"},
    {"ids:", "one or more job ids", "ids:1,2,3"},
    {"meta.", "a key or value in meta", "meta.batch_id:123"},
    {"nodes:", "host name", "nodes:machine@somehost"},
    {"priorities:", "number from 0 to 3", "priorities:1"},
    {"queues:", "queue name", "queues:default"},
    {"tags:", "tag name", "tags:super,duper"},
    {"workers:", "worker module", "workers:MyApp.SomeWorker"}
  ]

  @suggest_priority [
    {"0", "highest", "priorities:0"},
    {"1", "medium high", "priorities:1"},
    {"2", "medium low", "priorities:2"},
    {"3", "lowest", "priorities:3"}
  ]

  @known_qualifiers for {qualifier, _, _} <- @suggest_qualifier, into: MapSet.new(), do: qualifier

  @doc """
  Suggest completions from a search fragment.
  """
  @spec suggest(String.t(), Config.t()) :: [{String.t(), String.t(), String.t()}]
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

    subquery =
      if Enum.empty?(path) do
        field
        |> hint_limit_query(opts)
        |> join(:inner_lateral, [o], j in fragment("jsonb_each(?)", field(o, ^field)), on: true)
        |> select([_o, j], %{key: path_key(j.key, j.value)})
      else
        field
        |> hint_limit_query(opts)
        |> join(:inner_lateral, [o], j in fragment("jsonb_each(? #> ?)", field(o, ^field), ^path),
          on: true
        )
        |> select([_o, j], %{key: path_key(j.key, j.value)})
        |> where([j], fragment("jsonb_typeof(? #> ?) = 'object'", field(j, ^field), ^path))
      end

    query =
      subquery
      |> subquery()
      |> select([x], %{keys: fragment("jsonb_agg(distinct ?)", x.key)})

    case cache_query({field, :keys, path}, query, conf) do
      [%{keys: [_ | _] = keys}] ->
        keys
        |> Kernel.--(["return:"])
        |> restrict_suggestions(frag)

      _ ->
        []
    end
  end

  defp suggest_json_vals(_field, "", _frag, _conf, _opts), do: []

  defp suggest_json_vals(field, path, frag, conf, opts) do
    path = String.split(path, ".")

    subquery =
      field
      |> hint_limit_query(opts)
      |> select([j], %{vals: fragment("? #> ?", field(j, ^field), ^path)})

    query =
      subquery
      |> subquery()
      |> select([x], %{vals: fragment("jsonb_agg(distinct ?)", x.vals)})
      |> where([x], fragment("jsonb_typeof(?) = ANY(?)", x.vals, ~w(number string)))

    case cache_query({field, :vals, path}, query, conf) do
      [%{vals: [_ | _] = vals}] ->
        vals
        |> Enum.map(&to_string/1)
        |> Enum.map(&String.slice(&1, 0..90))
        |> restrict_suggestions(frag)

      _ ->
        []
    end
  end

  defp suggest_nodes(frag, conf, opts) do
    query =
      :nodes
      |> hint_limit_query(opts)
      |> select([j], fragment("?[1]", j.attempted_by))
      |> distinct(true)
      |> where([j], j.state not in ~w(available scheduled))

    :nodes
    |> cache_query(query, conf)
    |> restrict_suggestions(frag)
  end

  defp suggest_queues(frag, conf, opts) do
    query =
      :queues
      |> hint_limit_query(opts)
      |> select([j], j.queue)
      |> distinct(true)

    :queues
    |> cache_query(query, conf)
    |> restrict_suggestions(frag)
  end

  defp suggest_tags(frag, conf, opts) do
    query =
      :tags
      |> hint_limit_query(opts)
      |> select([j], %{tags: fragment("unnest(?)", j.tags)})
      |> subquery()
      |> select([x], %{tags: fragment("array_agg(distinct ?)", x.tags)})

    case cache_query(:tags, query, conf) do
      [%{tags: [_ | _] = tags}] -> restrict_suggestions(tags, frag)
      _ -> []
    end
  end

  defp suggest_workers(frag, conf, opts) do
    query =
      :workers
      |> hint_limit_query(opts)
      |> select([j], j.worker)
      |> distinct(true)

    :workers
    |> cache_query(query, conf)
    |> restrict_suggestions(frag)
  end

  defp cache_query(key, query, conf) do
    Cache.fetch(key, fn -> Repo.all(conf, query) end)
  end

  defp restrict_suggestions(suggestions, "") do
    suggestions
    |> Enum.sort()
    |> Enum.take(@suggest_limit)
    |> Enum.map(&{&1, "", ""})
  end

  defp restrict_suggestions(suggestions, frag) do
    suggestions
    |> Enum.filter(&(similarity(&1, frag) >= @suggest_threshold))
    |> Enum.sort_by(&{1.0 - similarity(&1, frag), &1}, :asc)
    |> Enum.take(@suggest_limit)
    |> Enum.map(&{&1, "", ""})
  end

  defp similarity(value, guess, boost \\ 0.5) do
    value = String.downcase(value)
    guess = String.downcase(guess)
    distance = String.jaro_distance(value, guess)

    if String.contains?(value, guess) do
      min(distance + boost, 1.0)
    else
      distance
    end
  end

  @doc """
  Complete a query by expanding the latest qualifier or fragment.
  """
  def complete(terms, conf) do
    case suggest(terms, conf) do
      [] ->
        terms

      [{match, _, _} | _] ->
        append(terms, match)
    end
  end

  @doc """
  Append to the terms string without any duplication.
  """
  def append(terms, choice) do
    choice = if String.match?(choice, ~r/[\s,]/), do: ~s("#{choice}"), else: choice

    cond do
      MapSet.member?(@known_qualifiers, choice) ->
        choice

      String.contains?(terms, ":") ->
        [qualifier, _] = String.split(terms, ":", parts: 2)

        "#{qualifier}:#{choice}"

      true ->
        terms
        |> String.reverse()
        |> String.split(["."], parts: 2)
        |> List.last()
        |> String.reverse()
        |> Kernel.<>(".#{choice}")
    end
  end

  # Queries

  def all_jobs(params, conf, opts \\ []) do
    params =
      @defaults
      |> Map.merge(params)
      |> Map.update!(:sort_by, &maybe_atomize/1)
      |> Map.update!(:sort_dir, &maybe_atomize/1)

    conditions = Enum.reduce(params, true, &filter/2)

    query =
      params.state
      |> jobs_limit_query(opts)
      |> select(^@list_fields)
      |> where(^conditions)
      |> order(params.sort_by, params.state, params.sort_dir)
      |> limit(^params.limit)

    Repo.all(conf, query)
  end

  defp jobs_limit_query(state, opts) do
    @states
    |> Map.fetch!(state)
    |> limit_query(:jobs_query_limit, opts)
  end

  defp hint_limit_query(qual, opts) do
    limit_query(qual, :hint_query_limit, opts)
  end

  defp limit_query(value, fun, opts) do
    resolver =
      if function_exported?(opts[:resolver], fun, 1) do
        opts[:resolver]
      else
        Resolver
      end

    case apply(resolver, fun, [value]) do
      :infinity ->
        Job

      limit ->
        sublimit =
          Job
          |> select([j], j.id - ^limit)
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

  def delete_jobs(%Config{} = conf, [_ | _] = job_ids) do
    Repo.delete_all(conf, only_ids(job_ids))

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
    {:args, String.trim(terms, "\"")}
  end

  defp parse_term("args." <> path_and_term) do
    parse_path(:args, path_and_term)
  end

  defp parse_term("ids:" <> ids) do
    parse_ints(:ids, ids)
  end

  defp parse_term("meta:" <> terms) do
    {:meta, String.trim(terms, "\"")}
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
        {field, [String.split(path, "."), String.trim(term, "\"")]}

      [path] ->
        {field, [String.split(path, "."), ""]}
    end
  end

  # Filter Helpers

  defp maybe_atomize(val) when is_binary(val), do: String.to_existing_atom(val)
  defp maybe_atomize(val), do: val

  defp only_ids(job_ids), do: where(Job, [j], j.id in ^job_ids)

  defp filter({:args, [path, term]}, condition) do
    dynamic([j], ^condition and fragment("? @> ?", j.args, ^gen_map(path, term)))
  end

  defp filter({:ids, ids}, condition) do
    dynamic([j], ^condition and j.id in ^ids)
  end

  defp filter({:meta, [path, term]}, condition) do
    dynamic([j], ^condition and fragment("? @> ?", j.meta, ^gen_map(path, term)))
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
      _ -> val
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
