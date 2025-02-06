defmodule Oban.Web.Helpers.CronHelper do
  @moduledoc false


  @doc """

  """
  @spec to_words(String.t()) :: String.t()
  def to_words("@reboot"), do: "After rebooting"
  def to_words("@annually"), do: to_words("0 0 1 1 *")
  def to_words("@yearly"), do: to_words("0 0 1 1 *")
  def to_words("@monthly"), do: to_words("0 0 1 * *")
  def to_words("@weekly"), do: to_words("0 0 * * 0")
  def to_words("@midnight"), do: to_words("0 0 * * *")
  def to_words("@daily"), do: to_words("0 0 * * *")
  def to_words("@hourly"), do: to_words("0 * * * *")

  def to_words(expr) when is_binary(expr) do
    expr
    |> String.split(~r/\s+/, trim: true, parts: 5)
    |> Enum.zip(~w(minute hour day month weekday))
    |> Enum.map(&part_to_words/1)
    |> Enum.reject(& &1 == "")
    |> Enum.join(", ")
  end

  defp part_to_words({field, unit}) do
    field
    |> String.split(~r/\s*,\s*/)
    |> Enum.map_join(" and ", &parse_part(&1, unit))
  end

  defp parse_part(part, unit) do
    cond do
      part == "*" and unit == "minute" ->
        "Every minute"

      part == "*" ->
        nil

      part =~ ~r/^\d+$/ ->
        part

      part =~ ~r/^\*\/[1-9]\d?$/ ->
        "*/" <> step = part

        "Every #{step} #{unit}s"

#       part =~ ~r/^\d+(\-\d+)?\/[1-9]\d?$/ ->
#         parse_range_step(part, range)

#       part =~ ~r/^\d+\-\d+$/ ->
#         parse_range(part, range)
    end
  end

  # defp parse_range_step(part, max_range) do
  #   [range, step] = String.split(part, "/")

  #   parse_step(step, parse_range(range, max_range))
  # end

  # defp parse_range(part, max_range) do
  #   case String.split(part, "-") do
  #     [rall] ->
  #       String.to_integer(rall)..Enum.max(max_range)

  #     [rmin, rmax] ->
  #       rmin = String.to_integer(rmin)
  #       rmax = String.to_integer(rmax)

  #       if rmin <= rmax do
  #         rmin..rmax
  #       else
  #         throw(
  #           {:error,
  #            "left side (#{rmin}) of a range must be less than or equal to the right side (#{rmax})"}
  #         )
  #       end
  #   end
  # end
end
