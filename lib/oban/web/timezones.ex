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
end
