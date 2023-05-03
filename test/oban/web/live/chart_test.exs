defmodule Oban.Web.Live.ChartTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Live.Chart

  describe "guide_values/2" do
    test "generating stepped values from 0 to the maximum" do
      assert ["0", "10", "20"] == Chart.guide_values(10, 2)
      assert ["0", "6", "12", "18"] == Chart.guide_values(10, 3)
      assert ["0", "5", "10", "15", "20"] == Chart.guide_values(10, 4)
      assert ["0", "5", "10", "15", "20"] == Chart.guide_values(15, 4)
    end

    test "rounding larger values" do
      assert [_, _, "130"] = Chart.guide_values(100, 2)
      assert [_, _, "1.3k"] = Chart.guide_values(1000, 2)
      assert [_, _, "12.5k"] = Chart.guide_values(10_000, 2)
      assert [_, _, "125k"] = Chart.guide_values(100_000, 2)
      assert [_, _, "1.3m"] = Chart.guide_values(1_000_000, 2)
      assert [_, _, "12.5m"] = Chart.guide_values(10_000_000, 2)
    end
  end
end
