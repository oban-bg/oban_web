defmodule ObanWeb.DashboardViewTest do
  use ExUnit.Case, async: true

  import ObanWeb.DashboardView, only: [job_time: 2]

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
end
