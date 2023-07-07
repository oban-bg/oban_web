defmodule Oban.Web.Search do
  @moduledoc false

  import Ecto.Query, only: [dynamic: 2, where: 2]

  alias Oban.Job

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

  @spec build(Ecto.Queryable.t(), String.t()) :: Ecto.Queryable.t()
  def build(query \\ Job, terms) when is_binary(terms) do
    conditions =
      terms
      |> parse()
      |> Enum.reduce(true, &compose/2)

    where(query, ^conditions)
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
