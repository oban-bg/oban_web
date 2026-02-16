defmodule Oban.Web.CronExprTest do
  use ExUnit.Case, async: true

  alias Oban.Web.CronExpr

  describe "describe/1" do
    test "cron aliases" do
      assert CronExpr.describe("@yearly") == "Yearly on January 1st"
      assert CronExpr.describe("@annually") == "Yearly on January 1st"
      assert CronExpr.describe("@monthly") == "Monthly on the 1st"
      assert CronExpr.describe("@weekly") == "Weekly on Sunday"
      assert CronExpr.describe("@daily") == "Daily at midnight"
      assert CronExpr.describe("@midnight") == "Daily at midnight"
      assert CronExpr.describe("@hourly") == "Every hour"
      assert CronExpr.describe("@reboot") == "At system reboot"
    end

    test "every minute" do
      assert CronExpr.describe("* * * * *") == "Every minute"
      assert CronExpr.describe("*/1 * * * *") == "Every minute"
    end

    test "every N minutes" do
      assert CronExpr.describe("*/5 * * * *") == "Every 5 minutes"
      assert CronExpr.describe("*/15 * * * *") == "Every 15 minutes"
      assert CronExpr.describe("*/30 * * * *") == "Every 30 minutes"
    end

    test "every hour" do
      assert CronExpr.describe("0 * * * *") == "Every hour"
      assert CronExpr.describe("0 */1 * * *") == "Every hour"
    end

    test "every N hours" do
      assert CronExpr.describe("0 */2 * * *") == "Every 2 hours"
      assert CronExpr.describe("0 */6 * * *") == "Every 6 hours"
      assert CronExpr.describe("0 */12 * * *") == "Every 12 hours"
    end

    test "every N hours at specific minute" do
      assert CronExpr.describe("30 */3 * * *") == "Every 3 hours at :30"
      assert CronExpr.describe("15 */2 * * *") == "Every 2 hours at :15"
      assert CronExpr.describe("0 */4 * * *") == "Every 4 hours"
    end

    test "daily at midnight" do
      assert CronExpr.describe("0 0 * * *") == "Daily at midnight"
    end

    test "daily at noon" do
      assert CronExpr.describe("0 12 * * *") == "Daily at noon"
    end

    test "daily at specific time" do
      assert CronExpr.describe("30 9 * * *") == "Daily at 9:30"
      assert CronExpr.describe("0 14 * * *") == "Daily at 14:00"
      assert CronExpr.describe("45 23 * * *") == "Daily at 23:45"
      assert CronExpr.describe("0 6 * * *") == "Daily at 6:00"
    end

    test "weekly on specific day" do
      assert CronExpr.describe("0 0 * * 0") == "Weekly on Sunday at 0:00"
      assert CronExpr.describe("0 0 * * 1") == "Weekly on Monday at 0:00"
      assert CronExpr.describe("0 0 * * SUN") == "Weekly on Sunday at 0:00"
      assert CronExpr.describe("0 0 * * MON") == "Weekly on Monday at 0:00"
      assert CronExpr.describe("0 0 * * 7") == "Weekly on Sunday at 0:00"
    end

    test "weekly on specific day at specific time" do
      assert CronExpr.describe("30 9 * * 1") == "Weekly on Monday at 9:30"
      assert CronExpr.describe("0 14 * * FRI") == "Weekly on Friday at 14:00"
    end

    test "monthly on specific day" do
      assert CronExpr.describe("0 0 1 * *") == "Monthly on the 1st at 0:00"
      assert CronExpr.describe("0 0 2 * *") == "Monthly on the 2nd at 0:00"
      assert CronExpr.describe("0 0 3 * *") == "Monthly on the 3rd at 0:00"
      assert CronExpr.describe("0 0 15 * *") == "Monthly on the 15th at 0:00"
      assert CronExpr.describe("0 0 22 * *") == "Monthly on the 22nd at 0:00"
      assert CronExpr.describe("0 0 31 * *") == "Monthly on the 31st at 0:00"
    end

    test "monthly on specific day at specific time" do
      assert CronExpr.describe("30 9 1 * *") == "Monthly on the 1st at 9:30"
      assert CronExpr.describe("0 14 15 * *") == "Monthly on the 15th at 14:00"
    end

    test "complex expressions with both DOM and DOW" do
      assert CronExpr.describe("0 0 1 * MON") == "The 1st, only on Mondays at 0:00"
      assert CronExpr.describe("0 0 1 * SUN,TUE-SAT") == "The 1st, except Mondays at 0:00"
      assert CronExpr.describe("0 0 2-31 * MON") == "Mondays, except the 1st at 0:00"

      assert CronExpr.describe("0 0 2-31 * SUN,TUE-SAT") ==
               "Daily except the 1st and Mondays at 0:00"
    end

    test "multiple hour values" do
      assert CronExpr.describe("0 8,9,10 * * *") == "Daily at 8:00, 9:00, and 10:00"
      assert CronExpr.describe("0 9,17 * * *") == "Daily at 9:00 and 17:00"
      assert CronExpr.describe("30 8,12,18 * * *") == "Daily at 8:30, 12:30, and 18:30"
    end

    test "returns nil for expressions with specific month" do
      assert CronExpr.describe("0 0 1 1 *") == nil
      assert CronExpr.describe("0 0 * 6 *") == nil
    end

    test "returns nil for invalid expressions" do
      assert CronExpr.describe("invalid") == nil
      assert CronExpr.describe("") == nil
    end

    test "returns nil for non-string input" do
      assert CronExpr.describe(nil) == nil
      assert CronExpr.describe(123) == nil
    end

    test "weekdays and weekends" do
      assert CronExpr.describe("0 9 * * 1-5") == "Weekdays at 9:00"
      assert CronExpr.describe("0 10 * * 0,6") == "Weekends at 10:00"
    end
  end
end
