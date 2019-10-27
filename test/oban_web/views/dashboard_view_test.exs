defmodule ObanWeb.DashboardViewTest do
  use ExUnit.Case, async: true

  import ObanWeb.DashboardView

  describe "time_ago_in_words/1" do
    test "time diffs in seconds are converted into relative times" do
      assert time_ago_in_words(0) == "00:00"
      assert time_ago_in_words(1) == "00:01"
      assert time_ago_in_words(60) == "01:00"
      assert time_ago_in_words(121) == "02:01"
      assert time_ago_in_words(7199) == "01:59:59"
    end
  end

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

  describe "state_count/2" do
    test "extracting the count from a list of state maps" do
      stats = [
        {"available", %{count: 0}},
        {"executing", %{count: 1}},
        {"scheduled", %{count: 2}}
      ]

      assert state_count(stats, "available") == 0
      assert state_count(stats, "executing") == 1
      assert state_count(stats, "scheduled") == 2
      assert state_count(stats, "untracked") == 0
    end
  end
end
