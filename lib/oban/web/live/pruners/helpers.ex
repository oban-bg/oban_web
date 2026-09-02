defmodule Oban.Web.Pruners.Helpers do
  @moduledoc false

  import Oban.Web.Helpers, only: [integer_to_delimited: 1, integer_to_estimate: 1]

  alias Oban.Web.Timing

  @default "default"
  @infinity "infinity"
  @match_keys ~w(queue worker state)a

  def default?(%{name: @default}), do: true
  def default?(_rule), do: false

  def match_pairs(%{match: %{} = match}) do
    for key <- @match_keys,
        value = Map.get(match, key),
        is_binary(value) and value != "",
        do: {key, value}
  end

  def match_pairs(_rule), do: []

  def mode_label(%{mode: %{kind: :max_age}}), do: "age"
  def mode_label(%{mode: %{kind: :max_len}}), do: "length"
  def mode_label(_rule), do: nil

  def format_mode(%{mode: %{kind: kind, value: value}}) when is_binary(value) do
    format_value(kind, value)
  end

  def format_mode(_rule), do: "—"

  defp format_value(_kind, @infinity), do: "Forever"

  defp format_value(:max_len, value) do
    case Integer.parse(value) do
      {count, ""} -> "#{integer_to_delimited(count)} jobs"
      _other -> value
    end
  end

  # Periods keep the unit they were written with, so only bare seconds need formatting.
  defp format_value(:max_age, value) do
    case Integer.parse(value) do
      {seconds, ""} -> Timing.to_words(seconds, relative: false)
      _other -> value
    end
  end

  defp format_value(_kind, value), do: value

  def estimate_limit(%{limit: limit}) when is_integer(limit), do: integer_to_estimate(limit)
  def estimate_limit(_rule), do: "—"

  @doc """
  Rule names are user input, so ids built from them must drop characters that aren't valid in DOM
  ids or query selectors.
  """
  def dom_name(%{name: name}), do: dom_name(name)
  def dom_name(name) when is_binary(name), do: String.replace(name, ~r/[^\w-]/, "-")

  @doc """
  Earlier rules that claim every job this rule matches, leaving it nothing to prune.

  Each rule excludes the jobs already claimed by the rules before it, so a rule whose match is
  fully covered by an earlier one never fires. Paused rules drop out of the chain entirely.
  """
  def shadowed_by(rule, rules) do
    rules
    |> Enum.take_while(&(&1.name != rule.name))
    |> Enum.reject(& &1.paused)
    |> Enum.filter(&covers?(&1, rule))
  end

  defp covers?(outer, inner) do
    inner_pairs = Map.new(match_pairs(inner))

    Enum.all?(match_pairs(outer), fn {field, value} -> Map.get(inner_pairs, field) == value end)
  end

  @doc """
  A rule's one-based place in the evaluation chain.
  """
  def position_of(rule, rules) do
    Enum.find_index(rules, &(&1.name == rule.name)) + 1
  end
end
