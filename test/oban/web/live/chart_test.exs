defmodule Oban.Web.Live.ChartTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Live.Chart

  describe "guide_values/2" do
    test "generating stepped values from 0 to the maximum" do
      assert ["0", "20"] == Chart.guide_values(10, 2)
      assert ["0", "10", "20"] == Chart.guide_values(10, 3)
      assert ["0", "6", "12", "18"] == Chart.guide_values(10, 4)
      assert ["0", "5", "10", "15", "20"] == Chart.guide_values(15, 5)
    end

    test "rounding larger values" do
      assert [_, "120"] = Chart.guide_values(100, 2)
      assert [_, "1.1k"] = Chart.guide_values(1000, 2)
      assert [_, "11k"] = Chart.guide_values(10_000, 2)
      assert [_, "110k"] = Chart.guide_values(100_000, 2)
      assert [_, "1.1m"] = Chart.guide_values(1_000_000, 2)
      assert [_, "11m"] = Chart.guide_values(10_000_000, 2)
    end

    test "defauling to a fixed value when max is 0" do
      assert ["0", "30"] == Chart.guide_values(0, 2)
      assert ["0", "15", "30"] == Chart.guide_values(0, 3)
    end
  end
end
