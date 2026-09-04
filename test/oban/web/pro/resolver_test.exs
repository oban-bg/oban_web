if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.ResolverTest do
    use Oban.Web.ProCase, async: true

    alias Ecto.Changeset
    alias Oban.Web.ProFixtures.Reports
    alias Oban.Web.Resolver

    describe "format_job_args/1" do
      test "decoding args from decorated jobs" do
        formatted =
          123
          |> Reports.new_weekly()
          |> Changeset.update_change(:args, &json_recode/1)
          |> Changeset.update_change(:meta, &json_recode/1)
          |> Changeset.apply_action!(:insert)
          |> Resolver.format_job_args()

        assert formatted =~ ~s|%{"arg" => [123]|
      end
    end

    defp json_recode(map) do
      map
      |> Oban.JSON.encode!()
      |> Oban.JSON.decode!()
    end
  end
end
