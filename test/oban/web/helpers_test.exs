defmodule Oban.Web.HelpersTest do
  use ExUnit.Case, async: true

  alias Oban.Web.{AccessError, Helpers}

  describe "encode_params/1" do
    import Helpers, only: [encode_params: 1]

    test "encoding fields with multiple values" do
      assert [nodes: "web-1,web-2"] = encode_params(nodes: ~w(web-1 web-2))
    end

    test "encoding fields with path qualifiers" do
      assert [args: "a++x"] = encode_params(args: [~w(a), "x"])
      assert [args: "a,b++x"] = encode_params(args: [~w(a b), "x"])
      assert [args: "a,b,c++x"] = encode_params(args: [~w(a b c), "x"])
    end
  end

  describe "decode_params/2" do
    import Helpers, only: [decode_params: 2]

    alias Oban.Web.JobQuery

    test "decoding fields with known integers" do
      assert %{limit: 1} = decode_params(%{"limit" => "1"}, JobQuery)
    end

    test "decoding params with multiple values" do
      assert %{nodes: ~w(web-1 web-2)} = decode_params(%{"nodes" => "web-1,web-2"}, JobQuery)
      assert %{queues: ~w(alpha gamma)} = decode_params(%{"queues" => "alpha,gamma"}, JobQuery)
      assert %{workers: ~w(A B)} = decode_params(%{"workers" => "A,B"}, JobQuery)
    end

    test "decoding params with path qualifiers" do
      assert %{args: [~w(a), "x"]} = decode_params(%{"args" => "a++x"}, JobQuery)
      assert %{args: [~w(a b), "x"]} = decode_params(%{"args" => "a,b++x"}, JobQuery)
      assert %{meta: [~w(a), "x"]} = decode_params(%{"meta" => "a++x"}, JobQuery)
    end

    test "decoding params not declared as qualifiers" do
      assert %{sort_by: "time", state: "executing"} =
               decode_params(%{"sort_by" => "time", "state" => "executing"}, JobQuery)
    end
  end

  describe "can?/2" do
    test "checking actions against access control lists" do
      assert Helpers.can?(:pause_queues, :all)
      refute Helpers.can?(:pause_queues, :read_only)
      assert Helpers.can?(:pause_queues, pause_queues: true)
      refute Helpers.can?(:pause_queues, pause_queues: false)
      refute Helpers.can?(:pause_queues, scale_queues: false)
    end
  end

  describe "enforce_access!/2" do
    test "raising a descriptive error when access is denied" do
      assert :ok = Helpers.enforce_access!(:pause_queues, :all)
      assert :ok = Helpers.enforce_access!(:pause_queues, pause_queues: true)

      error =
        assert_raise AccessError, fn ->
          Helpers.enforce_access!(:pause_queues, pause_queues: false)
        end

      assert error.action == :pause_queues
      assert Exception.message(error) =~ ":pause_queues action isn't allowed"
    end
  end

  describe "integer_to_delimited/1" do
    test "integers larger than three digits have are comma delimited" do
      assert Helpers.integer_to_delimited(1) == "1"
      assert Helpers.integer_to_delimited(100) == "100"
      assert Helpers.integer_to_delimited(1_000) == "1,000"
      assert Helpers.integer_to_delimited(10_000) == "10,000"
      assert Helpers.integer_to_delimited(100_000) == "100,000"
      assert Helpers.integer_to_delimited(1_000_000) == "1,000,000"
    end
  end

  describe "integer_to_estimate/1" do
    test "large integers are estimated to a rounded value with a unit size" do
      assert Helpers.integer_to_estimate(0) == "0"
      assert Helpers.integer_to_estimate(1) == "1"
      assert Helpers.integer_to_estimate(10) == "10"
      assert Helpers.integer_to_estimate(100) == "100"
      assert Helpers.integer_to_estimate(1000) == "1k"
      assert Helpers.integer_to_estimate(10_000) == "10k"
      assert Helpers.integer_to_estimate(100_000) == "100k"
      assert Helpers.integer_to_estimate(1_000_000) == "1m"
      assert Helpers.integer_to_estimate(10_000_000) == "10m"
      assert Helpers.integer_to_estimate(100_000_000) == "100m"
      assert Helpers.integer_to_estimate(1_000_000_000) == "1b"
    end

    test "values are rounded to business readable values" do
      assert Helpers.integer_to_estimate(1049) == "1k"
      assert Helpers.integer_to_estimate(1050) == "1.1k"
      assert Helpers.integer_to_estimate(1150) == "1.2k"
      assert Helpers.integer_to_estimate(1949) == "1.9k"
      assert Helpers.integer_to_estimate(1950) == "2k"
      assert Helpers.integer_to_estimate(10_949) == "11k"
      assert Helpers.integer_to_estimate(10_950) == "11k"
      assert Helpers.integer_to_estimate(150_499) == "150k"
      assert Helpers.integer_to_estimate(150_500) == "151k"
    end
  end
end
