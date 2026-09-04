defmodule Oban.Web.ResolverTest do
  use Oban.Web.Case, async: true

  alias Oban.Web.Resolver

  describe "jobs_query_limit/1" do
    test "overriding the default for the :completed state" do
      assert 100_000 == Resolver.jobs_query_limit(:completed)
      assert :infinity == Resolver.jobs_query_limit(:available)
      assert :infinity == Resolver.jobs_query_limit(:executing)
    end
  end

  describe "decode_recorded/2" do
    test "guarding against executable terms in safe mode" do
      assert_raise ArgumentError, fn ->
        %{fun: fn -> :no end}
        |> encode_term()
        |> Resolver.decode_recorded()
      end
    end

    test "allowing executable terms in unsafe mode" do
      term = [fn -> :ok end]

      assert term ==
               term
               |> encode_term()
               |> Resolver.decode_recorded([])
    end
  end

  describe "decode_signal/2" do
    test "round-tripping a payload through the same wire format as recorded" do
      payload = %{decision: "approved", amount: 42}

      assert payload ==
               payload
               |> encode_term()
               |> Resolver.decode_signal()
    end
  end

  describe "format_signal/2" do
    test "inspecting the decoded signal payload" do
      job = %Oban.Job{id: 1, args: %{}}
      encoded = encode_term(%{decision: "approved"})

      formatted = Resolver.format_signal(encoded, job)

      assert formatted =~ ~s|decision: "approved"|
    end
  end
end
