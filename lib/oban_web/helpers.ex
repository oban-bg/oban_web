defmodule ObanWeb.Helpers do
  @moduledoc false

  @spec integer_to_delimited(integer()) :: String.t()
  def integer_to_delimited(integer) when is_integer(integer) do
    integer
    |> Integer.to_charlist()
    |> Enum.reverse()
    |> Enum.chunk_every(3, 3, [])
    |> Enum.join(",")
    |> String.reverse()
  end

  @spec truncate(String.t(), Range.t()) :: String.t()
  def truncate(string, range \\ 0..90) do
    if String.length(string) > Enum.max(range) do
      String.slice(string, range) <> "…"
    else
      string
    end
  end
end
