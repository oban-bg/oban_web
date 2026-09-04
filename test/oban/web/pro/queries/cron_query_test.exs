if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.CronQueryTest do
    use Oban.Web.ProCase, async: true

    alias Oban.Web.CronQuery

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
  end
end
