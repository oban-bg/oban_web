defmodule ObanWeb.DashboardView do
  @moduledoc false

  use Phoenix.View, root: "lib/oban_web/templates", namespace: ObanWeb
  use Phoenix.HTML

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

  def job_args(args, range \\ 0..90) do
    inspected = inspect(args)

    if String.length(inspected) > Enum.max(range) do
      String.slice(inspected, range) <> "…"
    else
      inspected
    end
  end

  def job_error([%{"error" => error} | _]), do: inspect(error)
  def job_error(_errors), do: ""

  def time_ago_in_words(ellapsed) do
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
