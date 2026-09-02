defmodule Oban.Web.Search do
  @moduledoc false

  # A declarative engine for the search toolbar.
  #
  # Each page's query module declares its qualifiers as a keyword list and this module handles
  # parsing, suggesting, and completing terms against those declarations:
  #
  #     def qualifiers do
  #       [
  #         names: [desc: "cron entry name", example: "names:my-cron", suggest: &suggest_names/2],
  #         modes: [desc: "cron mode", example: "modes:static", suggest: @suggest_mode]
  #       ]
  #     end
  #
  # Each qualifier accepts the following options:
  #
  #   * desc/example — the description and example shown in the suggestion dropdown
  #
  #   * suggest — either a static list of {value, description, example} tuples, or a function of
  #     (fragment, conf) or (fragment, conf, opts) that looks values up dynamically; omit for
  #     qualifiers whose values can't be suggested, e.g. ids
  #
  #   * parse — how a qualifier's value is parsed, either :list for comma separated values (the
  #     default), :ints for comma separated integers, :string for the raw value, or a function
  #     that receives the raw value
  #
  #   * kind — :path marks dotted json qualifiers such as args. and meta., which take a suggest
  #     function of (path, fragment, conf, opts) and a suggest_keys function of (path, conf, opts)
  #
  #   * hidden — the qualifier is parsed from terms but never suggested or shown as a filter chip

  @ignored_chars ~w(; / \ ` ' = * ! ? # $ & + ^ | ~ < > ( \) { } [ ])

  @boundary ~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/

  # Suggestion tuning
  @suggest_limit 10
  @suggest_threshold 0.5

  @doc """
  Names of all qualifiers usable as filter chips in the search bar.
  """
  def filterable(qualifiers) do
    for {name, spec} <- qualifiers, not hidden?(spec), do: name
  end

  @doc """
  Names of all parseable qualifiers as strings, for allowing page params.
  """
  def known_params(qualifiers) do
    Enum.map(qualifiers, fn {name, _spec} -> to_string(name) end)
  end

  @doc """
  Parse a string of qualifiers and values into structured search terms.
  """
  def parse(terms, qualifiers) when is_binary(terms) and is_list(qualifiers) do
    terms
    |> String.split(@boundary, trim: true)
    |> Map.new(fn term ->
      term
      |> String.replace(@ignored_chars, "")
      |> parse_term(qualifiers)
    end)
  end

  @doc """
  Suggest qualifiers or values matching the final term.
  """
  def suggest(terms, qualifiers, conf, opts \\ []) when is_list(qualifiers) do
    terms
    |> String.split(@boundary)
    |> List.last()
    |> to_string()
    |> suggest_term(qualifiers, conf, opts)
  end

  @doc """
  Complete the terms with the top ranked suggestion.
  """
  def complete(terms, qualifiers, conf, opts \\ []) do
    case suggest(terms, qualifiers, conf, opts) do
      [] -> terms
      [{match, _, _} | _] -> append(terms, match, qualifiers)
    end
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

  def append(terms, choice, qualifiers) when is_list(qualifiers) do
    known = MapSet.new(displayed(qualifiers), fn {name, _desc, _example} -> name end)

    append(terms, choice, known)
  end

  @doc """
  Restrict suggestions by similarity to a given fragment.
  """
  def restrict_suggestions(suggestions, "") do
    suggestions
    |> Enum.sort()
    |> Enum.take(@suggest_limit)
    |> Enum.map(&{&1, "", ""})
  end

  def restrict_suggestions(suggestions, frag) do
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

  # Parsing

  defp parse_term(term, qualifiers) do
    Enum.find_value(qualifiers, {:none, ""}, fn {name, spec} ->
      cond do
        path?(spec) and String.starts_with?(term, "#{name}.") ->
          {name, parse_path(String.replace_prefix(term, "#{name}.", ""))}

        path?(spec) and String.starts_with?(term, "#{name}:") ->
          {name, term |> String.replace_prefix("#{name}:", "") |> String.trim()}

        String.starts_with?(term, "#{name}:") ->
          {name, parse_value(String.replace_prefix(term, "#{name}:", ""), spec)}

        true ->
          nil
      end
    end)
  end

  defp parse_path(rest) do
    case String.split(rest, ":", parts: 2) do
      [path, term] -> [String.split(path, "."), term]
      [path] -> [String.split(path, "."), ""]
    end
  end

  defp parse_value(value, spec) do
    case Keyword.get(spec, :parse, :list) do
      :list -> String.split(value, ",")
      :ints -> value |> String.split(",", trim: true) |> Enum.map(&String.to_integer/1)
      :string -> value
      fun when is_function(fun, 1) -> fun.(value)
    end
  end

  # Suggesting

  defp suggest_term("", qualifiers, _conf, _opts), do: displayed(qualifiers)

  defp suggest_term(last, qualifiers, conf, opts) do
    case String.split(last, ":", parts: 2) do
      [qual, frag] -> suggest_values(qual, frag, qualifiers, conf, opts)
      [frag] -> suggest_qualifiers(frag, qualifiers, conf, opts)
    end
  end

  defp suggest_values(qual, frag, qualifiers, conf, opts) do
    Enum.find_value(qualifiers, [], fn {name, spec} ->
      cond do
        hidden?(spec) ->
          nil

        path?(spec) and String.starts_with?(qual, "#{name}.") ->
          suggest_path_values(String.replace_prefix(qual, "#{name}.", ""), frag, spec, conf, opts)

        path?(spec) and to_string(name) == qual ->
          []

        to_string(name) == qual ->
          suggest_qualifier_values(frag, spec, conf, opts)

        true ->
          nil
      end
    end)
  end

  defp suggest_qualifier_values(frag, spec, conf, opts) do
    case Keyword.get(spec, :suggest) do
      values when is_list(values) -> filter_prefixed(values, frag)
      fun when is_function(fun, 2) -> fun.(frag, conf)
      fun when is_function(fun, 3) -> fun.(frag, conf, opts)
      nil -> []
    end
  end

  defp suggest_path_values(path, frag, spec, conf, opts) do
    case Keyword.get(spec, :suggest) do
      fun when is_function(fun, 4) -> fun.(path, frag, conf, opts)
      _missing -> []
    end
  end

  defp suggest_qualifiers(frag, qualifiers, conf, opts) do
    suggested =
      Enum.find_value(qualifiers, fn {name, spec} ->
        if path?(spec) and String.starts_with?(frag, "#{name}.") do
          suggest_path_keys(String.replace_prefix(frag, "#{name}.", ""), spec, conf, opts)
        end
      end)

    suggested || filter_prefixed(displayed(qualifiers), frag)
  end

  defp suggest_path_keys(path, spec, conf, opts) do
    case Keyword.get(spec, :suggest_keys) do
      fun when is_function(fun, 3) -> fun.(path, conf, opts)
      _missing -> []
    end
  end

  defp filter_prefixed(suggestions, frag) do
    for {value, _desc, _example} = suggestion <- suggestions,
        String.starts_with?(value, frag),
        do: suggestion
  end

  defp displayed(qualifiers) do
    for {name, spec} <- qualifiers, not hidden?(spec) do
      {display_name(name, spec), Keyword.get(spec, :desc, ""), Keyword.get(spec, :example, "")}
    end
  end

  defp display_name(name, spec) do
    if path?(spec), do: "#{name}.", else: "#{name}:"
  end

  defp hidden?(spec), do: Keyword.get(spec, :hidden, false)

  defp path?(spec), do: Keyword.get(spec, :kind) == :path
end
