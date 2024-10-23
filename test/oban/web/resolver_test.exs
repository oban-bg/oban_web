defmodule Oban.Web.ResolverTest do
  use ExUnit.Case, async: true

  alias Ecto.Changeset
  alias Oban.Web.Resolver

  defmodule Decorated do
    use Oban.Pro.Decorator

    @job true
    def foo(id), do: {:ok, id}
  end

  describe "format_job_args/1" do
    test "decoding args from decorated jobs" do
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

  defp json_recode(map) do
    map
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
