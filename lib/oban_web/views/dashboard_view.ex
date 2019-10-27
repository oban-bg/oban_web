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

  def state_count(stats, state) do
    state
    |> :proplists.get_value(stats, %{count: 0})
    |> Map.get(:count)
  end

  def integer_to_delimited(integer) when is_integer(integer) do
    integer
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3, 3, [])
    |> Enum.join(",")
    |> String.reverse()
  end

  def truncate(string, range \\ 0..90) do
    if String.length(string) > Enum.max(range) do
      String.slice(string, range) <> "…"
    else
      string
    end
  end

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
