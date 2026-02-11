defmodule Oban.Web.Crons.Helpers do
  @moduledoc false

  @doc """
  Parses and trims a string, returning nil for empty values.
  """
  def parse_string(nil), do: nil
  def parse_string(""), do: nil
  def parse_string(str), do: String.trim(str)

  @doc """
  Parses a string to an integer, returning nil for empty or invalid values.
  """
  def parse_int(nil), do: nil
  def parse_int(""), do: nil

  def parse_int(str) when is_binary(str) do
    case Integer.parse(str) do
      {num, ""} -> num
      _ -> nil
    end
  end

  @doc """
  Parses a comma-separated string into a list of trimmed tags. Returns nil for empty input.
  """
  def parse_tags(nil), do: nil
  def parse_tags(""), do: nil

  def parse_tags(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> nil
      tags -> tags
    end
  end

  @doc """
  Parses a JSON string into a map, returning nil for empty or invalid values.
  """
  def parse_json(nil), do: nil
  def parse_json(""), do: nil

  def parse_json(str) when is_binary(str) do
    case Oban.JSON.decode!(str) do
      map when is_map(map) -> map
      _ -> nil
    end
  rescue
    _ -> nil
  end

  @doc """
  Builds queue options from a list of queue structs.
  """
  def queue_options(queues) do
    queues
    |> Enum.map(fn %{name: name} -> {name, name} end)
    |> Enum.sort_by(&elem(&1, 0))
  end
end
