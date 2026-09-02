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
    with {:ok, name} <- parse_required(form.name, "Name is required"),
         {:ok, worker} <- parse_required(form.worker, "Worker is required"),
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

  defp parse_required(value, message) do
    case parse_string(value) do
      nil -> {:error, message}
      value -> {:ok, value}
    end
  end

  defp parse_expression(value) do
    with {:ok, expression} <- parse_required(value, "Expression is required") do
      case Expression.parse(expression) do
        {:ok, _parsed} -> {:ok, expression}
        {:error, _error} -> {:error, "Expression isn't a valid cron expression"}
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
          _other -> {:error, "Args must be a JSON object"}
        end
    end
  rescue
    _error -> {:error, "Args must be a JSON object"}
  end

  defp put_present(opts, _key, nil), do: opts
  defp put_present(opts, key, value), do: Map.put(opts, key, value)

  defp rescheduled?(form, baseline) do
    form.expression != baseline.expression or form.timezone != baseline.timezone
  end

  def format_failure(message) when is_binary(message), do: [message]

  def format_failure(%Ecto.Changeset{} = changeset), do: changeset_errors(changeset)
end
