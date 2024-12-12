defmodule Oban.Web.Search do
  @moduledoc false

  # Helpers for the search toolbar

  # Split terms using a positive lookahead that skips splitting within double quotes
  @split_pattern ~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/
  @ignored_chars ~w(; / \ ` ' = * ! ? # $ & + ^ | ~ < > ( \) { } [ ])

  @doc """
  Parse a string of qualifiers and values into structured search terms.
  """
  def parse(terms, parser) when is_binary(terms) and is_function(parser, 1) do
    terms
    |> String.split(@split_pattern)
    |> Map.new(fn term ->
      term
      |> String.replace(@ignored_chars, "")
      |> parser.()
    end)
  end

  @doc """
  Append to the terms string without any duplication.
  """
  def append(terms, choice, known)
      when is_binary(terms) and is_binary(choice) and is_struct(known, MapSet) do
    choice = if String.match?(choice, ~r/[\s,]/), do: ~s("#{choice}"), else: choice

    cond do
      MapSet.member?(known, choice) ->
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
end
