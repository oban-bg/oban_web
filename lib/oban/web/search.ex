defmodule Oban.Web.Search do
  @moduledoc false

  import Ecto.Query, only: [dynamic: 2, where: 2]

  alias Oban.{Config, Job}

  @suggest_limit 10
  @suggest_threshold 0.5

  @suggest_qualifier [
    {"args:", "a key or value in args", "args:video"},
    {"id:", "job id", "id:123"},
    {"meta:", "a key or value in meta", "meta.batch_id:123"},
    {"node:", "host name", "node:machine@somehost"},
    {"priority:", "number from 0 to 3", "priority:1"},
    {"queue:", "queue name", "queue:default"},
    {"state:", "job state", "state:executing"},
    {"tags:", "tag name", "tags:super,duper"},
    {"worker:", "worker module", "worker:MyApp.SomeWorker"}
  ]

  @suggest_priority [
    {"0", "highest", "priority:0"},
    {"1", "medium high", "priority:1"},
    {"2", "medium low", "priority:2"},
    {"3", "lowest", "priority:3"}
  ]

  @suggest_state [
    {"available", "available to run", "state:available"},
    {"cancelled", "purposefully stopped", "state:cancelled"},
    {"completed", "finished successfully", "state:completed"},
    {"discarded", "failed and won't run again", "state:discarded"},
    {"executing", "currently executing", "state:executing"},
    {"retryable", "failed and will retry in the future", "state:retryable"},
    {"scheduled", "scheduled for the future", "state:scheduled"}
  ]

  # Split terms using a positive lookahead that skips splitting within double quotes
  @split_pattern ~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/
  @ignored_chars ~W(; / \ ` ' = * ! ? # $ & + ^ | ~ < > ( \) { } [ ])

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

  @doc """
  Build an Ecto query from a string of parameters.

  ## Examples

      Search.build("state:executing queue:default")
  """
  @spec build(Ecto.Queryable.t(), String.t()) :: Ecto.Queryable.t()
  def build(query \\ Job, terms) when is_binary(terms) do
    conditions =
      terms
      |> parse()
      |> Enum.reduce(true, &compose/2)

    where(query, ^conditions)
  end

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
          ["id", _] -> []
          ["args" <> _, _] -> []
          ["meta" <> _, _] -> []
          ["node", frag] -> suggest_labels("node", frag, conf)
          ["queue", frag] -> suggest_labels("queue", frag, conf)
          ["priority", frag] -> suggest_static(@suggest_priority, frag)
          ["state", frag] -> suggest_static(@suggest_state, frag)
          ["tags", _] -> []
          ["worker", frag] -> suggest_labels("worker", frag, conf)
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
        if String.ends_with?(match, ":") do
          terms
          |> String.reverse()
          |> String.split(" ", parts: 2)
          |> case do
            [_head] ->
              match

            [_head, tail] ->
              tail
              |> String.reverse()
              |> Kernel.<>(" #{match}")
          end
        else
          terms
          |> String.reverse()
          |> String.split(":", parts: 2)
          |> List.last()
          |> String.reverse()
          |> Kernel.<>(":#{match}")
        end
    end
  end

  defp suggest_static(possibilities, fragment) do
    for {field, _, _} = suggest <- possibilities,
        String.starts_with?(field, fragment),
        do: suggest
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
    |> Enum.filter(&(similarity(&1, frag) > @suggest_threshold))
    |> Enum.sort_by(&similarity(&1, frag), :desc)
    |> Enum.take(@suggest_limit)
    |> Enum.map(&{&1, "", ""})
  end

  defp similarity(value, guess) do
    boost = 0.2
    value = String.downcase(value)
    distance = String.jaro_distance(value, guess)

    if String.starts_with?(value, guess) do
      distance + boost
    else
      distance - boost
    end
  end

  defp parse(terms) when is_binary(terms) do
    terms
    |> String.split(@split_pattern)
    |> Enum.map(fn term ->
      term
      |> String.replace(@ignored_chars, "")
      |> parse_term()
    end)
  end

  defp parse_term("priority:" <> priorities) when byte_size(priorities) > 0 do
    parse_ints(:priority, priorities)
  end

  defp parse_term("args:" <> terms) do
    {:args, String.trim(terms, "\"")}
  end

  defp parse_term("args." <> path_and_term) do
    parse_path(:args, path_and_term)
  end

  defp parse_term("id:" <> ids) when byte_size(ids) > 0 do
    parse_ints(:id, ids)
  end

  defp parse_term("meta:" <> terms) do
    {:meta, String.trim(terms, "\"")}
  end

  defp parse_term("meta." <> path_and_term) do
    parse_path(:meta, path_and_term)
  end

  defp parse_term("node:" <> nodes) do
    {:node, String.split(nodes, ",")}
  end

  defp parse_term("queue:" <> queues) do
    {:queue, String.split(queues, ",")}
  end

  defp parse_term("state:" <> states) do
    {:state, String.split(states, ",")}
  end

  defp parse_term("tags:" <> tags) do
    {:tags, String.split(tags, ",")}
  end

  defp parse_term("worker:" <> workers) do
    {:worker, String.split(workers, ",")}
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

    {field, String.split(path, "."), String.trim(term, "\"")}
  end

  defp compose({:args, terms}, condition) do
    dynamic([j], ^condition and json_search(j.args, ^terms))
  end

  defp compose({:args, parts, terms}, condition) do
    dynamic([j], ^condition and json_path_search(j.args, ^parts, ^terms))
  end

  defp compose({:id, ids}, condition) do
    dynamic([j], ^condition and j.id in ^ids)
  end

  defp compose({:meta, terms}, condition) do
    dynamic([j], ^condition and json_search(j.meta, ^terms))
  end

  defp compose({:meta, parts, terms}, condition) do
    dynamic([j], ^condition and json_path_search(j.meta, ^parts, ^terms))
  end

  defp compose({:node, nodes}, condition) do
    dynamic([j], ^condition and fragment("?[1]", j.attempted_by) in ^nodes)
  end

  defp compose({:queue, queues}, condition) do
    dynamic([j], ^condition and j.queue in ^queues)
  end

  defp compose({:priority, priorities}, condition) do
    dynamic([j], ^condition and j.priority in ^priorities)
  end

  defp compose({:state, states}, condition) do
    dynamic([j], ^condition and j.state in ^states)
  end

  defp compose({:tags, tags}, condition) do
    dynamic([j], ^condition and fragment("? && ?", j.tags, ^tags))
  end

  defp compose({:worker, workers}, condition) do
    dynamic([j], ^condition and j.worker in ^workers)
  end

  defp compose(_, condition), do: condition
end
