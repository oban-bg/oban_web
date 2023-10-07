defmodule Oban.Web.ResolverTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Resolver

  describe "jobs_query_limit/1" do
    test "overriding the default for the :completed state" do
      assert 100_000 == Resolver.jobs_query_limit(:completed)
      assert :infinity == Resolver.jobs_query_limit(:available)
      assert :infinity == Resolver.jobs_query_limit(:executing)
    end
  end
end
