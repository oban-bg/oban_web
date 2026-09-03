defmodule Oban.Web.Jobs.Form do
  @moduledoc false

  import Oban.Web.FormComponents,
    only: [changeset_errors: 1, decode_json: 1, parse_int: 1, parse_string: 1, parse_tags: 1]

  @cast_keys ~w(worker queue priority max_attempts scheduled_at tags args)

  def seed(job) do
    %{
      worker: job.worker,
      queue: job.queue,
      priority: to_string(job.priority),
      max_attempts: to_string(job.max_attempts),
      scheduled_at: format_datetime(job.scheduled_at),
      tags: format_tags(job.tags),
      args: format_args(job.args)
    }
  end

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
    |> String.slice(0, 19)
  end

  defp format_datetime(_datetime), do: ""

  defp format_tags(tags) when is_list(tags), do: Enum.join(tags, ", ")
  defp format_tags(_tags), do: ""

  defp format_args(args) when is_map(args), do: Oban.JSON.encode!(args)
  defp format_args(_args), do: "{}"

  def cast_params(params) do
    for key <- @cast_keys, is_binary(params[key]), into: %{} do
      {String.to_existing_atom(key), params[key]}
    end
  end

  # Only fields that differ from the stored job are included, so a save never rewrites what
  # wasn't touched. Every field is still validated because a blank or malformed value would
  # otherwise be indistinguishable from an untouched one.
  def build_changes(form, job) do
    with {:ok, worker} <- parse_required(form.worker, :worker, "Worker is required"),
         {:ok, queue} <- parse_required(form.queue, :queue, "Queue is required"),
         {:ok, priority} <- parse_priority(form.priority),
         {:ok, max_attempts} <- parse_max_attempts(form.max_attempts),
         {:ok, scheduled_at} <- parse_datetime(form.scheduled_at),
         {:ok, args} <- parse_args(form.args) do
      changes = %{
        worker: worker,
        queue: queue,
        priority: priority,
        max_attempts: max_attempts,
        scheduled_at: scheduled_at,
        tags: parse_tags(form.tags) || [],
        args: args
      }

      current = %{
        worker: job.worker,
        queue: job.queue,
        priority: job.priority,
        max_attempts: job.max_attempts,
        scheduled_at: truncate(job.scheduled_at),
        tags: job.tags || [],
        args: job.args
      }

      {:ok, Map.reject(changes, fn {key, value} -> value == Map.fetch!(current, key) end)}
    end
  end

  defp parse_required(value, field, message) do
    case parse_string(value) do
      nil -> {:error, {field, message}}
      value -> {:ok, value}
    end
  end

  defp parse_priority(value) do
    case parse_int(value) do
      priority when is_integer(priority) and priority in 0..9 -> {:ok, priority}
      _other -> {:error, {:priority, "Priority must be a number from 0 to 9"}}
    end
  end

  defp parse_max_attempts(value) do
    case parse_int(value) do
      attempts when is_integer(attempts) and attempts > 0 -> {:ok, attempts}
      _other -> {:error, {:max_attempts, "Max attempts must be a number of 1 or more"}}
    end
  end

  # Browsers omit the seconds from a datetime-local value when they're zero, so both forms have
  # to parse. Values are entered and stored in UTC.
  defp parse_datetime(value) do
    with {:ok, string} <- parse_required(value, :scheduled_at, "Scheduled at is required"),
         {:ok, datetime, 0} <- DateTime.from_iso8601(pad_seconds(string) <> "Z") do
      {:ok, truncate(datetime)}
    else
      {:error, {:scheduled_at, _message}} = error -> error
      _other -> {:error, {:scheduled_at, "Scheduled at must be a valid date and time"}}
    end
  end

  defp pad_seconds(<<_date::binary-size(10), "T", _time::binary-size(5)>> = string) do
    string <> ":00"
  end

  defp pad_seconds(string), do: string

  defp truncate(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)
  defp truncate(datetime), do: datetime

  defp parse_args(value) do
    value
    |> parse_string()
    |> decode_json()
    |> case do
      {:ok, args} when is_map(args) -> {:ok, args}
      {:ok, _other} -> {:error, {:args, "Args must be a JSON object"}}
      :error -> {:error, {:args, "Args must be valid JSON"}}
    end
  end

  def format_failure({_field, message}) when is_binary(message), do: [message]
  def format_failure(%Ecto.Changeset{} = changeset), do: changeset_errors(changeset)
  def format_failure(:not_found), do: ["Job no longer exists"]

  # The engine locks jobs while they run, so an update that races with a node picking the job
  # up fails the same way as one for a job that was deleted.
  def format_failure(:locked_or_not_found) do
    ["Job is locked by a running node or no longer exists"]
  end

  def format_failure(_reason), do: ["Failed to update job"]

  # Fields the failure points at, so the form can mark them invalid alongside the message.
  def invalid_fields({field, _message}), do: [field]

  def invalid_fields(%Ecto.Changeset{errors: errors}) do
    for {field, _error} <- errors, to_string(field) in @cast_keys, uniq: true, do: field
  end

  def invalid_fields(_failure), do: []
end
