defmodule Oban.Web.Timezones do
  @moduledoc false

  database = :oban_web |> :code.priv_dir() |> Path.join("timezones.txt")

  @external_resource database

  @timezones database
             |> File.read!()
             |> String.split("\n", trim: true)

  def all, do: @timezones

  def options do
    Enum.map(all(), &{&1, &1})
  end

  def options_with_blank do
    [{"", ""} | options()]
  end

  # Offsets need a time zone database, which the host app may not have. Without one the names
  # stand alone rather than failing the whole list.
  def options_with_offsets do
    now = DateTime.utc_now()

    Enum.map(all(), fn zone ->
      case DateTime.shift_zone(now, zone) do
        {:ok, shifted} -> {"#{zone} (#{format_offset(shifted)})", zone}
        {:error, _reason} -> {zone, zone}
      end
    end)
  end

  defp format_offset(%DateTime{utc_offset: utc_offset, std_offset: std_offset}) do
    total = utc_offset + std_offset
    sign = if total < 0, do: "-", else: "+"
    hours = total |> abs() |> div(3600)
    minutes = total |> abs() |> rem(3600) |> div(60)

    "UTC#{sign}#{pad(hours)}:#{pad(minutes)}"
  end

  defp pad(number), do: String.pad_leading(Integer.to_string(number), 2, "0")
end
