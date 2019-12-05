defmodule ObanWeb.ConfigTest do
  use ExUnit.Case, async: true

  alias ObanWeb.{Config, Repo}

  describe "new/1" do
    test "validating :repo as an ecto repo" do
      assert_raise ArgumentError, fn -> Config.new([]) end
      assert_raise ArgumentError, fn -> Config.new(repo: nil) end
      assert_raise ArgumentError, fn -> Config.new(repo: :repo) end
      assert_raise ArgumentError, fn -> Config.new(repo: Not.A.Repo) end

      assert %Config{} = Config.new(repo: Repo)
    end

    test "validating :stats as a boolean" do
      assert_raise ArgumentError, fn -> Config.new(repo: Repo, stats: :what) end
      assert_raise ArgumentError, fn -> Config.new(repo: Repo, stats: nil) end
      assert_raise ArgumentError, fn -> Config.new(repo: Repo, stats: Repo) end

      assert %Config{} = Config.new(repo: Repo, stats: false)
    end
  end
end
