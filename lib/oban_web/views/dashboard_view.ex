defmodule ObanWeb.DashboardView do
  @moduledoc false

  use ObanWeb, :view

  def queue_class(queue, steps \\ 12) when is_binary(queue) do
    key =
      queue
      |> :erlang.phash2()
      |> Integer.mod(steps)

    "queue-tag--#{key}"
  end

  def integer_to_delimited(integer) when is_integer(integer) do
    integer
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3, 3, [])
    |> Enum.join(",")
    |> String.reverse()
  end

  def job_args(args, range \\ 0..60) do
    inspected = inspect(args)

    if String.length(inspected) > Enum.max(range) do
      String.slice(inspected, range) <> "…"
    else
      inspected
    end
  end

  def job_error([%{"error" => error} | _]), do: inspect(error)
  def job_error(_errors), do: ""

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

  def job_worker(worker), do: String.trim_leading(worker, "Elixir.")

  defp pad(time), do: time |> to_string() |> String.pad_leading(2, "0")
end
