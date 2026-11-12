if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.CronQueryTest do
    use Oban.Web.ProCase, async: true

    import Ecto.Query, only: [where: 2]

    alias Oban.Web.{CronEntry, CronQuery}

    describe "all_crons/2" do
      @tag capture_log: true
      test "deriving the handler for decorated entries" do
        name =
          start_supervised_oban!(
            name: make_ref(),
            plugins: [{Oban.Cron, crontab: [decorated_cron_entry("0 * * * *")]}]
          )

        conf = Oban.config(name)
        handler = decorated_cron_name()

        assert [cron] = CronQuery.all_crons(%{}, conf)
        assert cron.worker == "Oban.Pro.Decorator"
        assert cron.handler == handler
        assert cron.decorated?

        assert [{^handler, _, _}] = CronQuery.suggest("workers:", conf)
        assert [_cron] = CronQuery.all_crons(%{workers: [handler]}, conf)
        assert [_cron] = CronQuery.all_crons(%{workers: ["Oban.Pro.Decorator"]}, conf)
        assert [] = CronQuery.all_crons(%{workers: ["MyApp.Other"]}, conf)

        stop_supervised(name)
      end
    end

    describe "insert_cron/2" do
      setup :start_oban

      test "inserting an entry with its options", %{conf: conf} do
        params = %{
          name: "nightly",
          worker: "MyApp.Nightly",
          expression: "0 0 * * *",
          opts: %{"queue" => "reports", "timezone" => "Europe/Paris"}
        }

        assert {:ok, entry} = CronQuery.insert_cron(params, conf)

        assert %{name: "nightly", worker: "MyApp.Nightly", expression: "0 0 * * *"} = entry
        assert %{paused: false, insertions: []} = reload(conf, "nightly")

        assert %{"queue" => "reports", "timezone" => "Europe/Paris"} =
                 reload(conf, "nightly").opts
      end

      test "rejecting invalid entries", %{conf: conf} do
        params = %{name: "nightly", worker: "MyApp.Nightly", expression: "0 0 * * *", opts: %{}}

        assert {:error, changeset} = CronQuery.insert_cron(%{params | name: nil}, conf)
        assert %{name: _} = Map.new(changeset.errors)

        assert {:error, changeset} = CronQuery.insert_cron(%{params | expression: "nope"}, conf)
        assert %{expression: _} = Map.new(changeset.errors)

        assert {:error, changeset} = CronQuery.insert_cron(%{params | opts: %{"bad" => 1}}, conf)
        assert %{opts: _} = Map.new(changeset.errors)
      end

      test "replacing an entry with the same name", %{conf: conf} do
        params = %{name: "nightly", worker: "MyApp.Nightly", expression: "0 0 * * *", opts: %{}}

        assert {:ok, _entry} = CronQuery.insert_cron(params, conf)

        put_insertions(conf, "nightly")

        assert {:ok, _entry} = CronQuery.insert_cron(%{params | worker: "MyApp.Other"}, conf)
        assert %{worker: "MyApp.Other", insertions: [_]} = reload(conf, "nightly")

        assert {:ok, _entry} = CronQuery.insert_cron(%{params | expression: "0 1 * * *"}, conf)
        assert %{expression: "0 1 * * *", insertions: []} = reload(conf, "nightly")
      end
    end

    describe "update_cron/3" do
      setup :start_oban

      setup %{conf: conf} do
        params = %{
          name: "nightly",
          worker: "MyApp.Nightly",
          expression: "0 0 * * *",
          opts: %{"timezone" => "Europe/Paris"}
        }

        {:ok, _entry} = CronQuery.insert_cron(params, conf)

        put_insertions(conf, "nightly")

        :ok
      end

      test "pausing keeps the tracked insertions", %{conf: conf} do
        assert {:ok, %{paused: true}} = CronQuery.update_cron("nightly", %{paused: true}, conf)
        assert %{paused: true, insertions: [_]} = reload(conf, "nightly")
      end

      test "renaming an entry", %{conf: conf} do
        assert {:ok, %{name: "daily"}} = CronQuery.update_cron("nightly", %{name: "daily"}, conf)

        assert %{insertions: [_]} = reload(conf, "daily")
        refute reload(conf, "nightly")
      end

      test "rescheduling resets the tracked insertions", %{conf: conf} do
        assert {:ok, _entry} = CronQuery.update_cron("nightly", %{expression: "0 1 * * *"}, conf)
        assert %{insertions: []} = reload(conf, "nightly")

        put_insertions(conf, "nightly")

        assert {:ok, _entry} = CronQuery.update_cron("nightly", %{opts: %{}}, conf)
        assert %{insertions: [], opts: opts} = reload(conf, "nightly")
        assert opts == %{}
      end

      test "rejecting invalid changes and unknown names", %{conf: conf} do
        assert {:error, changeset} = CronQuery.update_cron("nightly", %{expression: "nope"}, conf)
        assert %{expression: _} = Map.new(changeset.errors)

        assert {:error, message} = CronQuery.update_cron("missing", %{paused: true}, conf)
        assert message =~ "missing"
      end
    end

    describe "delete_cron/2" do
      setup :start_oban

      test "deleting an entry by name", %{conf: conf} do
        params = %{name: "nightly", worker: "MyApp.Nightly", expression: "0 0 * * *", opts: %{}}

        assert {:ok, _entry} = CronQuery.insert_cron(params, conf)
        assert {:ok, _entry} = CronQuery.delete_cron("nightly", conf)
        refute reload(conf, "nightly")

        assert {:error, message} = CronQuery.delete_cron("nightly", conf)
        assert message =~ "nightly"
      end
    end

    defp start_oban(_context) do
      name = start_supervised_oban!(name: make_ref())

      {:ok, conf: Oban.config(name)}
    end

    defp reload(conf, name), do: Oban.Repo.get(conf, CronEntry, name)

    defp put_insertions(conf, name) do
      query = where(CronEntry, name: ^name)

      Oban.Repo.update_all(conf, query, set: [insertions: [DateTime.utc_now()]])
    end
  end
end
