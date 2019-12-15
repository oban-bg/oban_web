defmodule ObanWeb.Timing do
  @moduledoc """
  Utilitiy functions for formatting and converting times.
  """

  @doc """
  Format ellapsed seconds into a timer format of "MM:SS" or "HH:MM:SS".

      iex> ObanWeb.Timing.to_duration(0)
      "00:00"

      iex> ObanWeb.Timing.to_duration(5)
      "00:05"

      iex> ObanWeb.Timing.to_duration(-5)
      "00:05"

      iex> ObanWeb.Timing.to_duration(60)
      "01:00"

      iex> ObanWeb.Timing.to_duration(65)
      "01:05"

      iex> ObanWeb.Timing.to_duration(7199)
      "01:59:59"
  """
  def to_duration(ellapsed) when is_integer(ellapsed) do
    ellapsed = abs(ellapsed)
    seconds = Integer.mod(ellapsed, 60)
    minutes = ellapsed |> Integer.mod(3_600) |> div(60)
    hours = div(ellapsed, 3_600)

    parts = [minutes, seconds]
    parts = if hours > 0, do: [hours | parts], else: parts

    parts
    |> Enum.map(&pad/1)
    |> Enum.join(":")
  end

  @doc """
  Format ellapsed seconds into a wordy format, based on "distance of time in words".

      iex> ObanWeb.Timing.to_words(0)
      "now"

      iex> ObanWeb.Timing.to_words(1)
      "in 1s"

      iex> ObanWeb.Timing.to_words(-1)
      "1s ago"

      iex> ObanWeb.Timing.to_words(-5)
      "5s ago"

      iex> ObanWeb.Timing.to_words(60)
      "in 1m"

      iex> ObanWeb.Timing.to_words(121)
      "in 2m"

      iex> ObanWeb.Timing.to_words(-60 * 60)
      "1h ago"

      iex> ObanWeb.Timing.to_words(60 * 60)
      "in 1h"

      iex> ObanWeb.Timing.to_words((60 * 60 * 24) - 1)
      "in 23h"

      iex> ObanWeb.Timing.to_words(60 * 60 * 24)
      "in 1d"

      iex> ObanWeb.Timing.to_words(60 * 60 * 24 * 5)
      "in 5d"

      iex> ObanWeb.Timing.to_words(60 * 60 * 24 * 30)
      "in 1mo"

      iex> ObanWeb.Timing.to_words(60 * 60 * 24 * 30 * 5)
      "in 5mo"

      iex> ObanWeb.Timing.to_words(60 * 60 * 24 * 365)
      "in 1yr"

      iex> ObanWeb.Timing.to_words(60 * 60 * 24 * 365 * 2)
      "in 2yr"
  """
  def to_words(ellapsed) when is_integer(ellapsed) do
    distance =
      case abs(ellapsed) do
        0 -> "now"
        n when n in 1..59 -> "#{n}s"
        n when n in 60..3_599 -> "#{div(n, 60)}m"
        n when n in 3_600..86_399 -> "#{div(n, 3_600)}h"
        n when n in 86_400..2_591_999 -> "#{div(n, 86_400)}d"
        n when n in 2_592_000..31_535_999 -> "#{div(n, 2_592_000)}mo"
        n -> "#{div(n, 31_536_000)}yr"
      end

    cond do
      ellapsed < 0 -> "#{distance} ago"
      ellapsed > 0 -> "in #{distance}"
      true -> distance
    end
  end

  defp pad(time) do
    time
    |> to_string()
    |> String.pad_leading(2, "0")
  end
end
