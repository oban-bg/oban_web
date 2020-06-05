defmodule Oban.Web.ConfigTest do
  use ExUnit.Case, async: true

  alias Oban.Web.{Config, Repo}

  describe "new/1" do
    test "validating :repo as an ecto repo" do
      assert_invalid(repo: nil)
      assert_invalid(repo: :repo)
      assert_invalid(repo: Not.A.Repo)

      assert_valid(repo: Repo)
    end

    test "validating :stats_interval as an interval" do
      assert_invalid(stats_interval: -1)
      assert_invalid(stats_interval: 0)
      assert_invalid(stats_interval: 1.0)
      assert_invalid(stats_interval: "1.0")

      assert_valid(stats_interval: 10)
      assert_valid(stats_interval: :timer.seconds(1))
    end

    test "validating :tick_interval as an interval" do
      assert_invalid(tick_interval: -1)
      assert_invalid(tick_interval: 0)
      assert_invalid(tick_interval: 1.0)
      assert_invalid(tick_interval: "1.0")

      assert_valid(tick_interval: 10)
      assert_valid(tick_interval: :timer.seconds(1))
    end

    test "validating :verbose as false or a log level" do
      assert_invalid(verbose: 1)
      assert_invalid(verbose: "false")
      assert_invalid(verbose: nil)
      assert_invalid(verbose: :warning)
      assert_invalid(verbose: true)

      assert_valid(verbose: false)
      assert_valid(verbose: :warn)
    end
  end

  defp assert_invalid(opts) do
    assert_raise ArgumentError, fn -> conf(opts) end
  end

  defp assert_valid(opts) do
    assert %Config{} = conf(opts)
  end

  defp conf(opts) do
    opts
    |> Keyword.put_new(:repo, Repo)
    |> Config.new()
  end
end
