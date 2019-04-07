defmodule ObanWebTest do
  use ExUnit.Case
  doctest ObanWeb

  test "greets the world" do
    assert ObanWeb.hello() == :world
  end
end
