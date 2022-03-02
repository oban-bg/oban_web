defmodule Oban.Web.Search do
  @moduledoc false

  import Ecto.Query, only: [dynamic: 2, where: 2]

  alias Oban.Job

  # Split terms using a positive lookahead that skips splitting within double quotes
  @split_pattern ~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/
  @ignored_chars ~W(; / \ ` ' = * ! ? # $ & + ^ | ~ < > ( \) { } [ ])

  @empty {[{:args, []}, {:meta, []}, {:tags, []}, {:worker, []}], []}

  defmacrop json_search(column, terms) do
    quote do
      fragment(
        """
        jsonb_to_tsvector(?, '["all"]') @@ websearch_to_tsquery(?)
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
        jsonb_to_tsvector(? #> ?, '["all"]') @@ websearch_to_tsquery(?)
        """,
        unquote(column),
        unquote(path),
        unquote(terms)
      )
    end
  end

  defmacro tags_search(column, terms) do
    quote do
      fragment(
        """
        array_to_tsvector(?) @@ websearch_to_tsquery(?)
        """,
        unquote(column),
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

  defp compose({:id, ids}, condition) do
    dynamic([j], ^condition and j.id in ^ids)
  end

  defp compose({:priority, priorities}, condition) do
    dynamic([j], ^condition and j.priority in ^priorities)
  end

  defp compose({fields, terms}, condition) do
    loose = "%#{terms}%"

    grouped =
      Enum.reduce(fields, false, fn
        {:args, []}, subcon -> dynamic([j], ^subcon or json_search(j.args, ^terms))
        {:meta, []}, subcon -> dynamic([j], ^subcon or json_search(j.meta, ^terms))
        {:args, path}, subcon -> dynamic([j], ^subcon or json_path_search(j.args, ^path, ^terms))
        {:meta, path}, subcon -> dynamic([j], ^subcon or json_path_search(j.meta, ^path, ^terms))
        {:tags, []}, subcon -> dynamic([j], ^subcon or tags_search(j.tags, ^terms))
        {:worker, []}, subcon -> dynamic([j], ^subcon or ilike(j.worker, ^loose))
        {:none, _}, subcon -> subcon
      end)

    dynamic([j], ^condition and ^grouped)
  end

  defp parse(terms) when is_binary(terms) do
    terms
    |> String.downcase()
    |> String.split(@split_pattern)
    |> Enum.map(&String.replace(&1, @ignored_chars, ""))
    |> parse(@empty, [])
  end

  defp parse([], ctx, acc) do
    [ctx | acc]
    |> List.flatten()
    |> Enum.reject(&match?([], elem(&1, 1)))
    |> Enum.map(&prep_terms/1)
  end

  defp parse(["priority:" <> priorities | tail], ctx, acc) do
    priorities =
      priorities
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)

    parse(tail, @empty, [{:priority, priorities}, ctx | acc])
  end

  defp parse(["id:" <> ids | tail], ctx, acc) do
    ids =
      ids
      |> String.split(",")
      |> Enum.map(&String.to_integer/1)

    parse(tail, @empty, [{:id, ids}, ctx | acc])
  end

  defp parse(["in:" <> fields | tail], {_, terms}, acc) do
    fields =
      fields
      |> String.split(",")
      |> Enum.map(fn field ->
        [head | tail] = String.split(field, ".")

        {field_to_atom(head), tail}
      end)

    parse(tail, @empty, [{fields, terms} | acc])
  end

  defp parse([term | tail], {fields, terms}, acc) do
    parse(tail, {fields, [term] ++ terms}, acc)
  end

  defp prep_terms({[_ | _] = fields, terms}), do: {fields, prep_terms(terms, [])}
  defp prep_terms(tuple), do: tuple

  defp prep_terms([], acc), do: acc |> IO.iodata_to_binary() |> String.trim_trailing()
  defp prep_terms(["not", term | tail], acc), do: prep_terms(tail, ["-", term, " " | acc])
  defp prep_terms([term, "not" | tail], acc), do: prep_terms(tail, ["-", term, " " | acc])
  defp prep_terms([term | tail], acc), do: prep_terms(tail, [term, " " | acc])

  defp field_to_atom("args"), do: :args
  defp field_to_atom("meta"), do: :meta
  defp field_to_atom("tags"), do: :tags
  defp field_to_atom("worker"), do: :worker
  defp field_to_atom(_field), do: :none
end
