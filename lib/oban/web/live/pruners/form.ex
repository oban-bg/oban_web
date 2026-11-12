defmodule Oban.Web.Pruners.Form do
  @moduledoc false

  import Oban.Web.FormComponents, only: [changeset_errors: 1, parse_int: 1, parse_string: 1]

  alias Oban.Period
  alias Oban.Web.PrunerRule

  @age_units ~w(seconds minutes hours days weeks months)
  @cast_keys ~w(name queue worker state kind age_value age_unit length_value limit timeout)
  @states ~w(completed cancelled discarded)

  defdelegate max_limit, to: PrunerRule

  def state_options do
    [{"Any state", ""} | Enum.map(@states, &{&1, &1})]
  end

  def kind_options do
    [{"For a max age", "age"}, {"To a max length", "length"}, {"Forever", "forever"}]
  end

  def unit_options, do: Enum.map(@age_units, &{&1, &1})

  # The pruner only runs once a minute, so a retention below sixty seconds isn't possible.
  def min_age(%{age_unit: "seconds"}), do: 60
  def min_age(_form), do: 1

  def seed do
    %{
      name: "",
      queue: "",
      worker: "",
      state: "",
      kind: "age",
      age_value: "",
      age_unit: "days",
      length_value: "",
      limit: "",
      timeout: "",
      archive: false,
      paused: false,
      lock_version: nil
    }
  end

  def seed(rule) do
    match = rule.match || %{}

    seed()
    |> Map.merge(seed_mode(rule))
    |> Map.merge(%{
      name: rule.name,
      queue: Map.get(match, :queue) || "",
      worker: Map.get(match, :worker) || "",
      state: Map.get(match, :state) || "",
      limit: to_string(rule.limit),
      timeout: to_string(rule.timeout),
      archive: rule.archive,
      paused: rule.paused,
      lock_version: rule.lock_version
    })
  end

  defp seed_mode(%{mode: %{value: "infinity"}}), do: %{kind: "forever"}

  defp seed_mode(%{mode: %{kind: :max_len, value: value}}) when is_binary(value) do
    %{kind: "length", length_value: value}
  end

  # Age values keep the unit they were written with, e.g. "7 days", while bare values are seconds.
  defp seed_mode(%{mode: %{kind: :max_age, value: value}}) when is_binary(value) do
    case String.split(value, " ", parts: 2) do
      [seconds] -> %{kind: "age", age_value: seconds, age_unit: "seconds"}
      [number, unit] -> %{kind: "age", age_value: number, age_unit: pluralize(unit)}
    end
  end

  defp seed_mode(_rule), do: %{}

  defp pluralize(unit) do
    if String.ends_with?(unit, "s"), do: unit, else: unit <> "s"
  end

  def cast_params(params) do
    cast =
      for key <- @cast_keys, is_binary(params[key]), into: %{} do
        {String.to_existing_atom(key), params[key]}
      end

    for key <- ~w(archive paused), is_binary(params[key]), reduce: cast do
      acc -> Map.put(acc, String.to_existing_atom(key), params[key] == "true")
    end
  end

  def build_opts(form) do
    with {:ok, name} <- parse_name(form.name),
         {:ok, mode} <- parse_retention(form) do
      match = %{
        queue: parse_string(form.queue),
        worker: parse_string(form.worker),
        state: parse_string(form.state)
      }

      params = %{name: name, archive: form.archive, match: match, mode: mode}

      {:ok, Map.merge(params, parse_limits(form))}
    end
  end

  defp parse_name(name) do
    case parse_string(name) do
      nil -> {:error, "Name is required"}
      name -> {:ok, name}
    end
  end

  defp parse_retention(%{kind: "forever"}), do: {:ok, %{kind: :max_age, value: "infinity"}}

  defp parse_retention(%{kind: "length"} = form) do
    case parse_int(form.length_value) do
      count when is_integer(count) and count > 0 ->
        {:ok, %{kind: :max_len, value: to_string(count)}}

      _other ->
        {:error, "Length must be a positive number of jobs"}
    end
  end

  defp parse_retention(%{kind: "age"} = form) do
    value = parse_int(form.age_value)

    cond do
      not is_integer(value) or value < 1 or form.age_unit not in @age_units ->
        {:error, "Age must be a positive number"}

      Period.to_seconds({value, String.to_existing_atom(form.age_unit)}) < 60 ->
        {:error, "Age must be at least a minute, the pruner only runs once a minute"}

      true ->
        {:ok, %{kind: :max_age, value: "#{value} #{form.age_unit}"}}
    end
  end

  defp parse_limits(form) do
    for {key, value} <- [limit: form.limit, timeout: form.timeout],
        parsed = parse_int(value),
        is_integer(parsed),
        into: %{},
        do: {key, parsed}
  end

  def format_failure(:not_found), do: ["Rule no longer exists"]

  def format_failure(message) when is_binary(message), do: [message]

  def format_failure(%Ecto.Changeset{} = changeset) do
    if stale?(changeset) do
      ["Rule was changed elsewhere — save again to apply your edits"]
    else
      changeset_errors(changeset)
    end
  end

  def stale?(%Ecto.Changeset{} = changeset) do
    Enum.any?(changeset.errors, fn {_field, {_message, opts}} -> opts[:stale] end)
  end

  def stale?(_failure), do: false
end
