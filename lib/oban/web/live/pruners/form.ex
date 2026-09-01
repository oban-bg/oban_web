defmodule Oban.Web.Pruners.Form do
  @moduledoc false

  import Oban.Web.FormComponents, only: [parse_int: 1, parse_string: 1]

  # Pruning by age bypasses row-number filtering with a constant of 100M, so limits anywhere
  # near it silently stop pruning. Pro's changeset enforces the same ceiling.
  @max_limit 10_000_000

  @age_units ~w(seconds minutes hours days weeks months)
  @cast_keys ~w(name queue worker state kind age_value age_unit length_value limit timeout)
  @states ~w(completed cancelled discarded)

  def max_limit, do: @max_limit

  def state_options do
    [{"Any state", ""} | Enum.map(@states, &{&1, &1})]
  end

  def kind_options do
    [{"For a maximum age", "age"}, {"To a maximum length", "length"}, {"Forever", "forever"}]
  end

  def unit_options, do: Enum.map(@age_units, &{&1, &1})

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

    if is_binary(params["archive"]) do
      Map.put(cast, :archive, params["archive"] == "true")
    else
      cast
    end
  end

  def build_opts(form) do
    with {:ok, name} <- parse_name(form.name),
         {:ok, retention} <- parse_retention(form) do
      opts =
        [
          name: name,
          queue: parse_string(form.queue),
          worker: parse_string(form.worker),
          state: parse_string(form.state),
          archive: form.archive
        ] ++ retention ++ parse_limits(form)

      {:ok, opts}
    end
  end

  defp parse_name(name) do
    case parse_string(name) do
      nil -> {:error, "Name is required"}
      name -> {:ok, name}
    end
  end

  defp parse_retention(%{kind: "forever"}), do: {:ok, [max_age: :infinity]}

  defp parse_retention(%{kind: "length"} = form) do
    case parse_int(form.length_value) do
      count when is_integer(count) and count > 0 -> {:ok, [max_len: count]}
      _other -> {:error, "Length must be a positive number of jobs"}
    end
  end

  defp parse_retention(%{kind: "age"} = form) do
    value = parse_int(form.age_value)

    if is_integer(value) and value > 0 and form.age_unit in @age_units do
      {:ok, [max_age: {value, String.to_existing_atom(form.age_unit)}]}
    else
      {:error, "Age must be a positive number"}
    end
  end

  defp parse_limits(form) do
    for {key, value} <- [limit: form.limit, timeout: form.timeout],
        parsed = parse_int(value),
        is_integer(parsed),
        do: {key, parsed}
  end

  def format_failure(:not_found), do: ["Rule no longer exists"]

  def format_failure(message) when is_binary(message), do: [message]

  def format_failure(%Ecto.Changeset{} = changeset) do
    if stale?(changeset) do
      ["Rule was changed elsewhere — review the current values, then save again"]
    else
      changeset
      |> Ecto.Changeset.traverse_errors(&interpolate_error/1)
      |> flatten_errors()
    end
  end

  def stale?(%Ecto.Changeset{} = changeset) do
    Enum.any?(changeset.errors, fn {_field, {_message, opts}} -> opts[:stale] end)
  end

  def stale?(_failure), do: false

  defp interpolate_error({message, opts}) do
    Regex.replace(~r"%{(\w+)}", message, fn _full, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end

  defp flatten_errors(errors, prefix \\ nil) do
    Enum.flat_map(errors, fn {key, value} ->
      label = if prefix, do: "#{prefix} #{key}", else: to_string(key)

      case value do
        %{} = nested -> flatten_errors(nested, label)
        messages when is_list(messages) -> Enum.map(messages, &"#{label} #{&1}")
      end
    end)
  end
end
