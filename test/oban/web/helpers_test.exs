defmodule Oban.Web.HelpersTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Helpers

  describe "can?/2" do
    test "checking actions against access control lists" do
      assert Helpers.can?(:pause_queues, :all)
      refute Helpers.can?(:pause_queues, :read_only)
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

  describe "integer_to_estimate/1" do
    test "large integers are estimated to a rounded value with a unit size" do
      assert Helpers.integer_to_estimate(0) == "0"
      assert Helpers.integer_to_estimate(1) == "1"
      assert Helpers.integer_to_estimate(10) == "10"
      assert Helpers.integer_to_estimate(100) == "100"
      assert Helpers.integer_to_estimate(1000) == "1k"
      assert Helpers.integer_to_estimate(10_000) == "10k"
      assert Helpers.integer_to_estimate(100_000) == "100k"
      assert Helpers.integer_to_estimate(1_000_000) == "1m"
      assert Helpers.integer_to_estimate(10_000_000) == "10m"
      assert Helpers.integer_to_estimate(100_000_000) == "100m"
      assert Helpers.integer_to_estimate(1_000_000_000) == "1b"
    end

    test "values are rounded to business readable values" do
      assert Helpers.integer_to_estimate(1049) == "1k"
      assert Helpers.integer_to_estimate(1050) == "1.1k"
      assert Helpers.integer_to_estimate(1150) == "1.2k"
      assert Helpers.integer_to_estimate(1949) == "1.9k"
      assert Helpers.integer_to_estimate(1950) == "2k"
      assert Helpers.integer_to_estimate(10_949) == "10.9k"
      assert Helpers.integer_to_estimate(10_950) == "11k"
    end
  end

  describe "iso8601_to_words/2" do
    test "converting an iso8601 string into time in words" do
      words =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(-1)
        |> NaiveDateTime.to_iso8601()
        |> Helpers.iso8601_to_words()

      assert words =~ ~r/[1,2]s ago/
    end
  end
end
