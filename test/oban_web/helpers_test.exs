defmodule ObanWeb.HelpersTest do
  use ExUnit.Case, async: true

  import ObanWeb.Helpers

  describe "integer_to_delimited/1" do
    test "integers larger than three digits have are comma delimited" do
      assert integer_to_delimited(1) == "1"
      assert integer_to_delimited(100) == "100"
      assert integer_to_delimited(1_000) == "1,000"
      assert integer_to_delimited(10_000) == "10,000"
      assert integer_to_delimited(100_000) == "100,000"
      assert integer_to_delimited(1_000_000) == "1,000,000"
    end
  end
end
