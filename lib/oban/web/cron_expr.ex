defmodule Oban.Web.CronExpr do
  @moduledoc false

  @days_of_week %{
    "0" => "Sunday",
    "1" => "Monday",
    "2" => "Tuesday",
    "3" => "Wednesday",
    "4" => "Thursday",
    "5" => "Friday",
    "6" => "Saturday",
    "7" => "Sunday",
    "SUN" => "Sunday",
    "MON" => "Monday",
    "TUE" => "Tuesday",
    "WED" => "Wednesday",
    "THU" => "Thursday",
    "FRI" => "Friday",
    "SAT" => "Saturday"
  }

  @doc """
  Convert a cron expression into a human-readable description.

  Returns a friendly string for common patterns, or nil for complex patterns
  that don't match known templates.
  """
  def describe(expression) when is_binary(expression) do
    case expression do
      "@yearly" -> "Yearly on January 1st"
      "@annually" -> "Yearly on January 1st"
      "@monthly" -> "Monthly on the 1st"
      "@weekly" -> "Weekly on Sunday"
      "@daily" -> "Daily at midnight"
      "@midnight" -> "Daily at midnight"
      "@hourly" -> "Every hour"
      "@reboot" -> "At system reboot"
      _ -> describe_parts(String.split(expression, " ", parts: 5))
    end
  end

  def describe(_), do: nil

  # Every minute
  defp describe_parts(["*", "*", "*", "*", "*"]), do: "Every minute"

  # Every N minutes
  defp describe_parts(["*/" <> step, "*", "*", "*", "*"]) do
    case Integer.parse(step) do
      {1, ""} -> "Every minute"
      {interval, ""} -> "Every #{interval} minutes"
      _ -> nil
    end
  end

  # Every hour (at minute 0)
  defp describe_parts(["0", "*", "*", "*", "*"]), do: "Every hour"

  # Every N hours at minute 0
  defp describe_parts(["0", "*/" <> step, "*", "*", "*"]) do
    case Integer.parse(step) do
      {1, ""} -> "Every hour"
      {interval, ""} -> "Every #{interval} hours"
      _ -> nil
    end
  end

  # Every N hours at specific minute
  defp describe_parts([minute, "*/" <> step, "*", "*", "*"]) do
    with {min, ""} <- Integer.parse(minute),
         {interval, ""} <- Integer.parse(step),
         true <- min in 0..59 do
      "Every #{interval} hours at :#{String.pad_leading("#{min}", 2, "0")}"
    else
      _ -> nil
    end
  end

  # Daily at midnight
  defp describe_parts(["0", "0", "*", "*", "*"]), do: "Daily at midnight"

  # Daily at noon
  defp describe_parts(["0", "12", "*", "*", "*"]), do: "Daily at noon"

  # Daily at specific time
  defp describe_parts([minute, hour, "*", "*", "*"]) do
    with {min, ""} <- Integer.parse(minute),
         {hrs, ""} <- Integer.parse(hour),
         true <- min in 0..59,
         true <- hrs in 0..23 do
      "Daily at #{format_time(hrs, min)}"
    else
      _ -> nil
    end
  end

  # Weekly on specific day at midnight
  defp describe_parts(["0", "0", "*", "*", dow]) do
    case parse_day_of_week(dow) do
      nil -> nil
      day_name -> "Weekly on #{day_name}"
    end
  end

  # Weekly on specific day at specific time
  defp describe_parts([minute, hour, "*", "*", dow]) do
    with {min, ""} <- Integer.parse(minute),
         {hrs, ""} <- Integer.parse(hour),
         true <- min in 0..59,
         true <- hrs in 0..23,
         day_name when not is_nil(day_name) <- parse_day_of_week(dow) do
      "Weekly on #{day_name} at #{format_time(hrs, min)}"
    else
      _ -> nil
    end
  end

  # Monthly on specific day at midnight
  defp describe_parts(["0", "0", day_of_month, "*", "*"]) do
    case Integer.parse(day_of_month) do
      {dom, ""} when dom in 1..31 -> "Monthly on the #{ordinal(dom)}"
      _ -> nil
    end
  end

  # Monthly on specific day at specific time
  defp describe_parts([minute, hour, day_of_month, "*", "*"]) do
    with {min, ""} <- Integer.parse(minute),
         {hrs, ""} <- Integer.parse(hour),
         {dom, ""} <- Integer.parse(day_of_month),
         true <- min in 0..59,
         true <- hrs in 0..23,
         true <- dom in 1..31 do
      "Monthly on the #{ordinal(dom)} at #{format_time(hrs, min)}"
    else
      _ -> nil
    end
  end

  # Fallback - return nil for complex expressions
  defp describe_parts(_), do: nil

  # Time formatting helpers

  defp format_time(0, 0), do: "midnight"
  defp format_time(12, 0), do: "noon"

  defp format_time(hour, minute) do
    {display_hour, period} = to_12_hour(hour)
    minute_str = String.pad_leading("#{minute}", 2, "0")

    "#{display_hour}:#{minute_str} #{period}"
  end

  defp to_12_hour(0), do: {12, "AM"}
  defp to_12_hour(12), do: {12, "PM"}
  defp to_12_hour(hour) when hour < 12, do: {hour, "AM"}
  defp to_12_hour(hour), do: {hour - 12, "PM"}

  defp parse_day_of_week(dow) do
    Map.get(@days_of_week, String.upcase(dow))
  end

  defp ordinal(num) when num in [1, 21, 31], do: "#{num}st"
  defp ordinal(num) when num in [2, 22], do: "#{num}nd"
  defp ordinal(num) when num in [3, 23], do: "#{num}rd"
  defp ordinal(num), do: "#{num}th"
end
