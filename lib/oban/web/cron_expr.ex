defmodule Oban.Web.CronExpr do
  @moduledoc false

  @days_of_week_names %{
    0 => "Sunday",
    1 => "Monday",
    2 => "Tuesday",
    3 => "Wednesday",
    4 => "Thursday",
    5 => "Friday",
    6 => "Saturday"
  }

  @days_of_week_translations %{
    "SUN" => 0,
    "MON" => 1,
    "TUE" => 2,
    "WED" => 3,
    "THU" => 4,
    "FRI" => 5,
    "SAT" => 6
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
      _ -> describe_parsed(expression)
    end
  end

  def describe(_), do: nil

  defp describe_parsed(expression) do
    with [min, hrs, dom, "*", dow] <- String.split(expression, " ", parts: 5),
         {:ok, parsed_min} <- parse_field(min),
         {:ok, parsed_hrs} <- parse_field(hrs),
         {:ok, parsed_dom} <- parse_field(dom),
         {:ok, parsed_dow} <- parse_field(dow, @days_of_week_translations) do
      combine_description(parsed_min, parsed_hrs, parsed_dom, parsed_dow)
    else
      _ -> nil
    end
  end

  # Field Parsing

  defp parse_field(field, translations \\ %{}) do
    parts =
      field
      |> String.split(",")
      |> Enum.map(&parse_part(&1, translations))

    if Enum.any?(parts, &(&1 == :error)) do
      :error
    else
      {:ok, parts}
    end
  end

  defp parse_part("*", _translations), do: :wildcard

  defp parse_part("*/" <> step, _translations) do
    case Integer.parse(step) do
      {num, ""} when num > 0 -> {:step, num}
      _ -> :error
    end
  end

  defp parse_part(part, translations) do
    if String.contains?(part, "-") do
      parse_range(part, translations)
    else
      parse_value(part, translations)
    end
  end

  defp parse_range(part, translations) do
    with [start_str, end_str] <- String.split(part, "-", parts: 2),
         {:ok, start_val} <- translate_or_parse(start_str, translations),
         {:ok, end_val} <- translate_or_parse(end_str, translations) do
      {:range, start_val, end_val}
    else
      _ -> :error
    end
  end

  defp parse_value(part, translations) do
    case translate_or_parse(part, translations) do
      {:ok, val} -> {:value, val}
      :error -> :error
    end
  end

  defp translate_or_parse(str, translations) do
    upper = String.upcase(str)

    with :error <- Map.fetch(translations, upper) do
      case Integer.parse(str) do
        {num, ""} -> {:ok, num}
        _ -> :error
      end
    end
  end

  # Description Combination

  defp combine_description(min, hrs, dom, dow) do
    if dom == [:wildcard] and dow == [:wildcard] do
      describe_time(min, hrs)
    else
      combine_date_time(min, hrs, dom, dow)
    end
  end

  defp describe_time([:wildcard], [:wildcard]), do: "Every minute"
  defp describe_time([{:step, 1}], [:wildcard]), do: "Every minute"
  defp describe_time([{:step, step}], [:wildcard]), do: "Every #{step} minutes"
  defp describe_time([{:value, 0}], [:wildcard]), do: "Every hour"
  defp describe_time([{:value, 0}], [{:step, 1}]), do: "Every hour"
  defp describe_time([{:value, 0}], [{:step, step}]), do: "Every #{step} hours"

  defp describe_time([{:value, min}], [{:step, step}]) when min in 0..59 do
    "Every #{step} hours at :#{String.pad_leading("#{min}", 2, "0")}"
  end

  defp describe_time([{:value, 0}], [{:value, 0}]), do: "Daily at midnight"
  defp describe_time([{:value, 0}], [{:value, 12}]), do: "Daily at noon"

  defp describe_time([{:value, min}], [{:value, hr}]) when min in 0..59 and hr in 0..23 do
    "Daily at #{format_time_24h(hr, min)}"
  end

  defp describe_time([{:value, min}], hours) when is_list(hours) and min in 0..59 do
    times =
      Enum.map(hours, fn
        {:value, hr} when hr in 0..23 -> format_time_24h(hr, min)
        _ -> nil
      end)

    if Enum.any?(times, &is_nil/1) do
      nil
    else
      "Daily at #{format_list(times)}"
    end
  end

  defp describe_time(_, _), do: nil

  defp combine_date_time(min, hrs, dom, dow) do
    time = extract_time(min, hrs)
    date_desc = describe_date(dom, dow)

    case {time, date_desc} do
      {nil, _} -> nil
      {_, nil} -> nil
      {{0, 0}, desc} -> "#{desc} at 0:00"
      {{hrs, min}, desc} -> "#{desc} at #{format_time_24h(hrs, min)}"
    end
  end

  defp extract_time([{:value, min}], [{:value, hrs}]) when min in 0..59 and hrs in 0..23 do
    {hrs, min}
  end

  defp extract_time(_, _), do: nil

  # Date Description (DOM and DOW combination)

  defp describe_date([:wildcard], dow) do
    describe_dow(dow)
  end

  defp describe_date(dom, [:wildcard]) do
    describe_dom(dom)
  end

  defp describe_date(dom, dow) do
    describe_combined_dom_dow(dom, dow)
  end

  # Day of Month Description

  defp describe_dom([{:value, day}]) when day in 1..31 do
    "Monthly on the #{ordinal(day)}"
  end

  defp describe_dom(parts) when is_list(parts) do
    values = expand_dom_parts(parts)

    case excluded_dom(values) do
      {:ok, day} ->
        "Daily except the #{ordinal(day)}"

      :error ->
        days = extract_dom_values(parts)

        if days != [] do
          "On the #{format_list(Enum.map(days, &ordinal/1))}"
        else
          nil
        end
    end
  end

  defp describe_dom(_), do: nil

  defp excluded_dom(values) do
    case Enum.to_list(1..31) -- values do
      [excluded] -> {:ok, excluded}
      _ -> :error
    end
  end

  defp expand_dom_parts(parts) do
    parts
    |> Enum.flat_map(fn
      {:value, val} -> [val]
      {:range, start_val, end_val} -> Enum.to_list(start_val..end_val)
      _ -> []
    end)
    |> Enum.sort()
  end

  defp extract_dom_values(parts) do
    Enum.flat_map(parts, fn
      {:value, val} when val in 1..31 ->
        [val]

      {:range, start_val, end_val} when start_val in 1..31 and end_val in 1..31 ->
        Enum.to_list(start_val..end_val)

      _ ->
        []
    end)
  end

  # Day of Week Description

  defp describe_dow([{:value, day}]) when day in 0..7 do
    "Weekly on #{day_name(normalize_dow(day))}"
  end

  defp describe_dow(parts) when is_list(parts) do
    values = expand_dow_parts(parts)

    cond do
      values == [1, 2, 3, 4, 5] ->
        "Weekdays"

      values == [0, 6] ->
        "Weekends"

      length(values) == 6 ->
        {:ok, day} = excluded_dow(values)

        "Daily except #{day_name(day)}s"

      values != [] ->
        "On #{format_list(Enum.map(values, &day_name/1))}"

      true ->
        nil
    end
  end

  defp describe_dow(_), do: nil

  defp expand_dow_parts(parts) do
    parts
    |> Enum.flat_map(fn
      {:value, val} -> [normalize_dow(val)]
      {:range, start_val, end_val} -> Enum.map(start_val..end_val, &normalize_dow/1)
      _ -> []
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp normalize_dow(7), do: 0
  defp normalize_dow(day), do: day

  defp excluded_dow(values) do
    case Enum.to_list(0..6) -- values do
      [excluded] -> {:ok, excluded}
      _ -> :error
    end
  end

  # Combined DOM and DOW description

  defp describe_combined_dom_dow(dom, dow) do
    dom_values = expand_dom_parts(dom)
    dow_values = expand_dow_parts(dow)

    case {dom_values, excluded_dom(dom_values), dow_values, excluded_dow(dow_values)} do
      {[dom_day], _, [dow_day], _} ->
        "The #{ordinal(dom_day)}, only on #{day_name(dow_day)}s"

      {[dom_day], _, _, {:ok, excluded}} ->
        "The #{ordinal(dom_day)}, except #{day_name(excluded)}s"

      {_, {:ok, excluded}, [dow_day], _} ->
        "#{day_name(dow_day)}s, except the #{ordinal(excluded)}"

      {_, {:ok, dom_excluded}, _, {:ok, dow_excluded}} ->
        "Daily except the #{ordinal(dom_excluded)} and #{day_name(dow_excluded)}s"

      _ ->
        nil
    end
  end

  # Helper functions

  defp day_name(num), do: Map.get(@days_of_week_names, num, "Unknown")

  defp format_time_24h(hr, min) do
    "#{hr}:#{String.pad_leading("#{min}", 2, "0")}"
  end

  defp format_list([single]), do: single
  defp format_list([first, second]), do: "#{first} and #{second}"

  defp format_list(items) when length(items) > 2 do
    {init, [last]} = Enum.split(items, -1)
    "#{Enum.join(init, ", ")}, and #{last}"
  end

  defp format_list(_), do: nil

  defp ordinal(num) when num in [1, 21, 31], do: "#{num}st"
  defp ordinal(num) when num in [2, 22], do: "#{num}nd"
  defp ordinal(num) when num in [3, 23], do: "#{num}rd"
  defp ordinal(num), do: "#{num}th"
end
