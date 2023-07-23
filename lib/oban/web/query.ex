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

  # Split terms using a positive lookahead that skips splitting within double quotes
  @split_pattern ~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/
  @ignored_chars ~W(; / \ ` ' = * ! ? # $ & + ^ | ~ < > ( \) { } [ ])

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

  @suggest_limit 10
  @suggest_threshold 0.5

  @suggest_qualifier [
    {"args:", "a key or value in args", "args:video"},
    {"meta:", "a key or value in meta", "meta.batch_id:123"},
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

  @doc """
  Suggest completions from a search fragment.
  """
  @spec suggest(String.t(), Config.t()) :: [{String.t(), String.t(), String.t()}]
  def suggest(terms, conf) do
    terms
    |> String.split(@split_pattern)
    |> List.last()
    |> to_string()
    |> case do
      "" ->
        @suggest_qualifier

      last ->
        case String.split(last, ":", parts: 2) do
          ["args" <> _, _] -> []
          ["meta" <> _, _] -> []
          ["nodes", frag] -> suggest_labels("node", frag, conf)
          ["queues", frag] -> suggest_labels("queue", frag, conf)
          ["priorities", frag] -> suggest_static(@suggest_priority, frag)
          ["tags", frag] -> suggest_tags(frag, conf)
          ["workers", frag] -> suggest_labels("worker", frag, conf)
          [frag] -> suggest_static(@suggest_qualifier, frag)
          _ -> @suggest_qualifier
        end
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
    cond do
      String.ends_with?(choice, ":") ->
        terms
        |> String.reverse()
        |> String.split(" ", parts: 2)
        |> case do
          [_head] ->
            choice

          [_head, tail] ->
            tail
            |> String.reverse()
            |> Kernel.<>(" #{choice}")
        end

      true ->
        terms
        |> String.reverse()
        |> String.split(":", parts: 2)
        |> List.last()
        |> String.reverse()
        |> Kernel.<>(":#{choice}")
    end
  end

  # Queries

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

  def cancel_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Oban.cancel_all_jobs(name, only_ids(job_ids))

    :ok
  end

  def delete_jobs(%Config{} = conf, [_ | _] = job_ids) do
    Repo.delete_all(conf, only_ids(job_ids))

    :ok
  end

  def retry_jobs(%Config{name: name}, [_ | _] = job_ids) do
    Oban.retry_all_jobs(name, only_ids(job_ids))

    :ok
  end

  # Parsing Helpers

  defp parse_term("args:" <> terms) do
    {:args, String.trim(terms, "\"")}
  end

  defp parse_term("args." <> path_and_term) do
    parse_path(:args, path_and_term)
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
    [path, term] = String.split(path_and_term, ":", parts: 2)

    {field, [String.split(path, "."), String.trim(term, "\"")]}
  end

  # Suggest Helpers

  defp suggest_static(possibilities, fragment) do
    for {field, _, _} = suggest <- possibilities,
        String.starts_with?(field, fragment),
        do: suggest
  end

  defp suggest_tags(frag, conf) do
    query =
      Oban.Job
      |> select([j], j.tags)
      |> order_by(desc: :id)
      |> limit(100_000)

    conf
    |> Oban.Repo.all(query)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort_by(&similarity(&1, frag), :desc)
    |> Enum.take(@suggest_limit)
    |> Enum.map(&{&1, "", ""})
  end

  defp suggest_labels(label, "", conf) do
    conf.name
    |> Oban.Met.labels(label)
    |> Enum.take(@suggest_limit)
    |> Enum.map(&{&1, "", ""})
  end

  defp suggest_labels(label, frag, conf) do
    frag = String.downcase(frag)

    conf.name
    |> Oban.Met.labels(label)
    |> Enum.filter(&(similarity(&1, frag) >= @suggest_threshold))
    |> Enum.sort_by(&similarity(&1, frag), :desc)
    |> Enum.take(@suggest_limit)
    |> Enum.map(&{&1, "", ""})
  end

  defp similarity(value, guess, boost \\ 0.5) do
    value = String.downcase(value)
    guess = String.downcase(guess)
    distance = String.jaro_distance(value, guess)

    if String.contains?(value, guess) do
      distance + boost
    else
      distance
    end
  end

  # Filter Helpers

  defp maybe_atomize(val) when is_binary(val), do: String.to_existing_atom(val)
  defp maybe_atomize(val), do: val

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
