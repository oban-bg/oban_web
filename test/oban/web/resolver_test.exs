defmodule Oban.Web.ResolverTest do
  use ExUnit.Case, async: true

  alias Ecto.Changeset
  alias Oban.Web.Resolver

  describe "format_job_args/1" do
    @tag :pro
    test "decoding args from decorated jobs" do
      defmodule Decorated do
        use Oban.Pro.Decorator

        @job true
        def foo(id), do: {:ok, id}
      end

      formatted =
        123
        |> Decorated.new_foo()
        |> Changeset.update_change(:args, &json_recode/1)
        |> Changeset.update_change(:meta, &json_recode/1)
        |> Changeset.apply_action!(:insert)
        |> Resolver.format_job_args()

      assert formatted =~ ~s|%{"arg" => [123]|
    end
  end

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
        |> encode_recorded()
        |> Resolver.decode_recorded()
      end
    end

    test "allowing executable terms in unsafe mode" do
      term = [fn -> :ok end]

      assert term ==
               term
               |> encode_recorded()
               |> Resolver.decode_recorded([])
    end
  end

  defp encode_recorded(data) do
    data
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
  end

  defp json_recode(map) do
    map
    |> Oban.JSON.encode!()
    |> Oban.JSON.decode!()
  end
end
