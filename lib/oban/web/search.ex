defmodule Oban.Web.Search do
  @moduledoc false

  alias Oban.Config

  @suggest_limit 10
  @suggest_threshold 0.8

  @suggest_qualifier [
    {"args:", "a key or value in args", "args:video"},
    {"meta:", "a key or value in meta", "meta.batch_id:123"},
    {"nodes:", "host name", "node:machine@somehost"},
    {"priorities:", "number from 0 to 3", "priority:1"},
    {"queues:", "queue name", "queue:default"},
    {"state:", "job state", "state:executing"},
    {"tags:", "tag name", "tags:super,duper"},
    {"workers:", "worker module", "worker:MyApp.SomeWorker"}
  ]

  @suggest_priority [
    {"0", "highest", "priorities:0"},
    {"1", "medium high", "priorities:1"},
    {"2", "medium low", "priorities:2"},
    {"3", "lowest", "priorities:3"}
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
          ["state", frag] -> suggest_static(@suggest_state, frag)
          ["tags", _] -> []
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
    boost = 0.5
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

  # Filter Parsing

  defp parse_term({:priority, priorities}) when byte_size(priorities) > 0 do
    parse_ints(:priority, priorities)
  end

  defp parse_term({:args, path_and_term}) do
    {:args, parse_path(:args, path_and_term)}
  end

  defp parse_term({:id, ids}) when byte_size(ids) > 0 do
    parse_ints(:id, ids)
  end

  defp parse_term({:meta, path_and_term}) do
    {:args, parse_path(:meta, path_and_term)}
  end

  defp parse_term({type, value}) when type in ~w(node queue state tags worker)a do
    {type, String.split(value, ",")}
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

end
