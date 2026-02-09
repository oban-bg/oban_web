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
      assert CronExpr.describe("30 9 * * *") == "Daily at 9:30 AM"
      assert CronExpr.describe("0 14 * * *") == "Daily at 2:00 PM"
      assert CronExpr.describe("45 23 * * *") == "Daily at 11:45 PM"
      assert CronExpr.describe("0 6 * * *") == "Daily at 6:00 AM"
    end

    test "weekly on specific day" do
      assert CronExpr.describe("0 0 * * 0") == "Weekly on Sunday"
      assert CronExpr.describe("0 0 * * 1") == "Weekly on Monday"
      assert CronExpr.describe("0 0 * * SUN") == "Weekly on Sunday"
      assert CronExpr.describe("0 0 * * MON") == "Weekly on Monday"
      assert CronExpr.describe("0 0 * * 7") == "Weekly on Sunday"
    end

    test "weekly on specific day at specific time" do
      assert CronExpr.describe("30 9 * * 1") == "Weekly on Monday at 9:30 AM"
      assert CronExpr.describe("0 14 * * FRI") == "Weekly on Friday at 2:00 PM"
    end

    test "monthly on specific day" do
      assert CronExpr.describe("0 0 1 * *") == "Monthly on the 1st"
      assert CronExpr.describe("0 0 2 * *") == "Monthly on the 2nd"
      assert CronExpr.describe("0 0 3 * *") == "Monthly on the 3rd"
      assert CronExpr.describe("0 0 15 * *") == "Monthly on the 15th"
      assert CronExpr.describe("0 0 21 * *") == "Monthly on the 21st"
      assert CronExpr.describe("0 0 22 * *") == "Monthly on the 22nd"
      assert CronExpr.describe("0 0 23 * *") == "Monthly on the 23rd"
      assert CronExpr.describe("0 0 31 * *") == "Monthly on the 31st"
    end

    test "monthly on specific day at specific time" do
      assert CronExpr.describe("30 9 1 * *") == "Monthly on the 1st at 9:30 AM"
      assert CronExpr.describe("0 14 15 * *") == "Monthly on the 15th at 2:00 PM"
    end

    test "returns nil for complex expressions" do
      # Multiple values
      assert CronExpr.describe("0,30 * * * *") == nil
      # Ranges
      assert CronExpr.describe("0-30 * * * *") == nil
      # Complex patterns
      assert CronExpr.describe("0 0 1 1 *") == nil
      # Invalid expressions
      assert CronExpr.describe("invalid") == nil
      assert CronExpr.describe("") == nil
    end

    test "returns nil for non-string input" do
      assert CronExpr.describe(nil) == nil
      assert CronExpr.describe(123) == nil
    end
  end
end
