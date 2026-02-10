for repo <- [Oban.Web.Repo, Oban.Web.SQLiteRepo, Oban.Web.MyXQLRepo] do
  defmodule Module.concat(repo, CronQueryTest) do
    use Oban.Web.Case, async: true

    alias Oban.Config
    alias Oban.Web.CronQuery

    @repo repo

    @engine (case repo do
               Oban.Web.MyXQLRepo -> Oban.Engines.Dolphin
               Oban.Web.Repo -> Oban.Engines.Basic
               Oban.Web.SQLiteRepo -> Oban.Engines.Lite
             end)

    @conf Config.new(repo: @repo, engine: @engine)

    @moduletag myxql: repo == Oban.Web.MyXQLRepo
    @moduletag sqlite: repo == Oban.Web.SQLiteRepo

    describe "cron_history/2" do
      test "fetching job history for a single cron" do
        insert!(%{}, meta: %{cron_name: "cron-a"}, state: "completed")
        insert!(%{}, meta: %{cron_name: "cron-a"}, state: "executing")
        insert!(%{}, meta: %{cron_name: "cron-b"}, state: "completed")

        history = cron_history("cron-a")

        assert length(history) == 2
        assert Enum.all?(history, &(&1.state in ["completed", "executing"]))
      end

      test "returning empty list when cron has no history" do
        history = cron_history("nonexistent-cron")

        assert history == []
      end

      test "returning jobs in ascending order by id" do
        insert!(%{}, meta: %{cron_name: "cron-a"}, state: "completed")
        insert!(%{}, meta: %{cron_name: "cron-a"}, state: "executing")

        history = cron_history("cron-a")

        assert [first, second] = history
        assert first.state == "completed"
        assert second.state == "executing"
      end
    end

    describe "crontab_history/2" do
      test "fetching history for multiple crons" do
        insert!(%{}, meta: %{cron_name: "cron-a"}, state: "completed")
        insert!(%{}, meta: %{cron_name: "cron-a"}, state: "executing")
        insert!(%{}, meta: %{cron_name: "cron-b"}, state: "completed")

        crontab = [
          {"* * * * *", "WorkerA", [], "cron-a", false, false},
          {"0 * * * *", "WorkerB", [], "cron-b", false, false}
        ]

        history = crontab_history(crontab)

        assert Map.has_key?(history, "cron-a")
        assert Map.has_key?(history, "cron-b")
        assert length(history["cron-a"]) == 2
        assert length(history["cron-b"]) == 1
      end

      test "returning empty maps for crons with no history" do
        crontab = [
          {"* * * * *", "WorkerA", [], "cron-a", false, false}
        ]

        history = crontab_history(crontab)

        assert history["cron-a"] == []
      end

      test "handling mix of crons with and without history" do
        insert!(%{}, meta: %{cron_name: "cron-a"}, state: "completed")

        crontab = [
          {"* * * * *", "WorkerA", [], "cron-a", false, false},
          {"0 * * * *", "WorkerB", [], "cron-b", false, false}
        ]

        history = crontab_history(crontab)

        assert length(history["cron-a"]) == 1
        assert history["cron-b"] == []
      end
    end

    defp cron_history(name) do
      CronQuery.cron_history(name, @conf)
    end

    defp crontab_history(crontab) do
      CronQuery.crontab_history(crontab, @conf)
    end

    defp insert!(args, opts) do
      opts = Keyword.put_new(opts, :conf, @conf)

      insert_job!(args, opts)
    end
  end
end
