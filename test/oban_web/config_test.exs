defmodule ObanWeb.ConfigTest do
  use ExUnit.Case, async: true

  alias ObanWeb.{Config, Repo}

  describe "new/1" do
    test "validating :repo as an ecto repo" do
      assert_invalid(repo: nil)
      assert_invalid(repo: :repo)
      assert_invalid(repo: Not.A.Repo)

      assert_valid(repo: Repo)
    end

    test "validating :stats as a boolean" do
      assert_invalid(stats: :what)
      assert_invalid(stats: nil)
      assert_invalid(stats: Repo)

      assert_valid(stats: true)
      assert_valid(stats: false)
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
