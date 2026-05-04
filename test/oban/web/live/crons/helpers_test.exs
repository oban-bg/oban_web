defmodule Oban.Web.Crons.HelpersTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Crons.Helpers

  describe "maybe_to_unix/1" do
    test "converts a timestamp to unix milliseconds" do
      datetime = ~U[2026-01-01 00:00:00.000Z]

      assert is_integer(Helpers.maybe_to_unix(datetime))
    end

    test "returns an empty string for nil or :unknown" do
      assert "" == Helpers.maybe_to_unix(nil)
      assert "" == Helpers.maybe_to_unix(:unknown)
    end
  end
end
