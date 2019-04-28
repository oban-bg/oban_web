defmodule ObanWeb.DashboardViewTest do
  use ExUnit.Case, async: true

  import ObanWeb.DashboardView, only: [integer_to_delimited: 1, job_time: 2]

  describe "job_time/2" do
    test "timestamps are converted into relative times" do
      now = ~N[2019-04-16 13:00:00]

      assert job_time(~N[2019-04-16 13:00:00], now) == "00:00"
      assert job_time(~N[2019-04-16 13:00:01], now) == "00:01"
      assert job_time(~N[2019-04-16 13:01:00], now) == "01:00"
      assert job_time(~N[2019-04-16 14:59:59], now) == "01:59:59"
      assert job_time(~N[2019-04-17 12:59:59], now) == "23:59:59"
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
end
