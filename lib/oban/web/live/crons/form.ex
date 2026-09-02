defmodule Oban.Web.Crons.Form do
  @moduledoc false

  import Oban.Web.FormComponents,
    only: [changeset_errors: 1, parse_int: 1, parse_string: 1, parse_tags: 1]

  alias Oban.Cron.Expression

  @cast_keys ~w(name worker expression queue timezone priority max_attempts tags args)

  # Every option the form edits. Options outside this list, like meta, are carried over from the
  # stored entry untouched.
  @form_opts ~w(args guaranteed max_attempts priority queue tags timezone)

  def seed(cron) do
    opts = cron.opts || %{}

    %{
      name: cron.name,
      worker: cron.worker,
      expression: cron.expression,
      queue: Map.get(opts, "queue") || "",
      timezone: Map.get(opts, "timezone") || "",
      priority: to_string(Map.get(opts, "priority")),
      max_attempts: to_string(Map.get(opts, "max_attempts")),
      guaranteed: Map.get(opts, "guaranteed") == true,
      tags: format_tags(Map.get(opts, "tags")),
      args: format_args(Map.get(opts, "args"))
    }
  end

  defp format_tags(tags) when is_list(tags), do: Enum.join(tags, ", ")
  defp format_tags(_tags), do: ""

  defp format_args(args) when is_map(args) and map_size(args) > 0, do: Oban.JSON.encode!(args)
  defp format_args(_args), do: ""

  def cast_params(params) do
    cast =
      for key <- @cast_keys, is_binary(params[key]), into: %{} do
        {String.to_existing_atom(key), params[key]}
      end

    if is_binary(params["guaranteed"]) do
      Map.put(cast, :guaranteed, params["guaranteed"] == "true")
    else
      cast
    end
  end

  # The stored options are replaced wholesale so that clearing a field removes the option, rather
  # than merging a blank over the previous value. Changing the schedule or timezone resets the
  # entry's insertion history, which only happens when the expression is part of the update.
  def build_opts(form, baseline, current_opts) do
    with {:ok, name} <- parse_required(form.name, :name, "Name is required"),
         {:ok, worker} <- parse_required(form.worker, :worker, "Worker is required"),
         {:ok, expression} <- parse_expression(form.expression),
         {:ok, args} <- parse_args(form.args) do
      opts =
        (current_opts || %{})
        |> Map.drop(@form_opts)
        |> put_present("args", args)
        |> put_present("guaranteed", form.guaranteed == true || nil)
        |> put_present("max_attempts", parse_int(form.max_attempts))
        |> put_present("priority", parse_int(form.priority))
        |> put_present("queue", parse_string(form.queue))
        |> put_present("tags", parse_tags(form.tags))
        |> put_present("timezone", parse_string(form.timezone))

      params = [name: name, worker: worker, opts: opts]

      if rescheduled?(form, baseline) do
        {:ok, [{:expression, expression} | params]}
      else
        {:ok, params}
      end
    end
  end

  defp parse_required(value, field, message) do
    case parse_string(value) do
      nil -> {:error, {field, message}}
      value -> {:ok, value}
    end
  end

  defp parse_expression(value) do
    with {:ok, expression} <- parse_required(value, :expression, "Expression is required") do
      case Expression.parse(expression) do
        {:ok, _parsed} -> {:ok, expression}
        {:error, _error} -> {:error, {:expression, "Expression isn't a valid cron expression"}}
      end
    end
  end

  defp parse_args(value) do
    case parse_string(value) do
      nil ->
        {:ok, nil}

      json ->
        case Oban.JSON.decode!(json) do
          args when is_map(args) -> {:ok, args}
          _other -> {:error, {:args, "Args must be a JSON object"}}
        end
    end
  rescue
    _error -> {:error, {:args, "Args must be a JSON object"}}
  end

  defp put_present(opts, _key, nil), do: opts
  defp put_present(opts, key, value), do: Map.put(opts, key, value)

  # Consequences that aren't visible from the fields themselves. Renaming starts a fresh history
  # because jobs are tracked by cron name, and rescheduling clears the insertion tracking that
  # guaranteed mode uses to backfill missed runs.
  def advisories(form, baseline) do
    consequences = [
      {renamed?(form, baseline),
       "Saving under a new name starts a fresh history. Jobs already inserted stay under the old name."},
      {baseline.guaranteed and rescheduled?(form, baseline),
       "Saving a new schedule resets guaranteed insertion. Runs missed before the change won't be backfilled."}
    ]

    for {applies?, message} <- consequences, applies?, do: message
  end

  defp renamed?(form, baseline) do
    case parse_string(form.name) do
      nil -> false
      name -> name != baseline.name
    end
  end

  defp rescheduled?(form, baseline) do
    form.expression != baseline.expression or form.timezone != baseline.timezone
  end

  def format_failure({_field, message}) when is_binary(message), do: [message]

  def format_failure(message) when is_binary(message), do: [message]

  def format_failure(%Ecto.Changeset{} = changeset), do: changeset_errors(changeset)

  # Fields the failure points at, so the form can mark them invalid alongside the message.
  def invalid_fields({field, _message}), do: [field]

  def invalid_fields(%Ecto.Changeset{errors: errors}) do
    for {field, _error} <- errors, to_string(field) in @cast_keys, uniq: true, do: field
  end

  def invalid_fields(_failure), do: []
end
