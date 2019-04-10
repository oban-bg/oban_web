defmodule ObanWeb.LayoutView do
  @moduledoc false

  use ObanWeb, :view

  def inline_asset(filename) do
    "../../priv/assets"
    |> Path.expand(__DIR__)
    |> Path.join(filename)
    |> IO.inspect()

    :oban_web
    |> :code.priv_dir()
    |> Path.join("assets")
    |> Path.join(filename)
    |> File.read!()
  end
end
