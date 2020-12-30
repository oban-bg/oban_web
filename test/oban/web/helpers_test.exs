defmodule Oban.Web.HelpersTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Helpers

  describe "can?/2" do
    test "checking actions against access control lists" do
      assert Helpers.can?(:pause_queues, :all)
      refute Helpers.can?(:pause_queues, :read)
      assert Helpers.can?(:pause_queues, pause_queues: true)
      refute Helpers.can?(:pause_queues, pause_queues: false)
      refute Helpers.can?(:pause_queues, scale_queues: false)
    end
  end

  describe "integer_to_delimited/1" do
    test "integers larger than three digits have are comma delimited" do
      assert Helpers.integer_to_delimited(1) == "1"
      assert Helpers.integer_to_delimited(100) == "100"
      assert Helpers.integer_to_delimited(1_000) == "1,000"
      assert Helpers.integer_to_delimited(10_000) == "10,000"
      assert Helpers.integer_to_delimited(100_000) == "100,000"
      assert Helpers.integer_to_delimited(1_000_000) == "1,000,000"
    end
  end

  describe "iso8601_to_words/2" do
    test "converting an iso8601 string into time in words" do
      words =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(-1)
        |> NaiveDateTime.to_iso8601()
        |> Helpers.iso8601_to_words()

      assert words =~ "1s ago"
    end
  end
end
