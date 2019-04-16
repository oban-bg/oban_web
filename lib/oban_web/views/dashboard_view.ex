defmodule ObanWeb.DashboardView do
  @moduledoc false

  use ObanWeb, :view

  alias Oban.Job

  def queue_class(%Job{queue: queue}) do
    key =
      queue
      |> :erlang.phash2()
      |> Integer.mod(8)

    "queue-tag--#{key}"
  end

  def job_worker(%Job{worker: worker}), do: String.trim_leading(worker, "Elixir.")

  def job_args(%Job{args: args}, range \\ 0..60) do
    inspected = inspect(args)

    if String.length(inspected) > Enum.max(range) do
      String.slice(inspected, range) <> "…"
    else
      inspected
    end
  end

  @spec job_time(Job.t()) :: binary()
  def job_time(%Job{attempted_at: then}), do: job_time(then)

  def job_time(then, now \\ NaiveDateTime.utc_now()) do
    ellapsed =
      then
      |> NaiveDateTime.diff(now)
      |> abs()

    seconds = Integer.mod(ellapsed, 60)
    minutes = ellapsed |> Integer.mod(3_600) |> div(60)
    hours = div(ellapsed, 3_600)

    parts = [minutes, seconds]
    parts = if hours > 0, do: [hours | parts], else: parts

    parts
    |> Enum.map(&pad/1)
    |> Enum.join(":")
  end

  defp pad(time), do: time |> to_string() |> String.pad_leading(2, "0")
end
