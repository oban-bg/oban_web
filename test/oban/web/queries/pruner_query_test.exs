defmodule Oban.Web.PrunerQueryTest do
  use Oban.Web.Case

  alias Oban.Config
  alias Oban.Pro.Pruner
  alias Oban.Web.PrunerQuery

  @moduletag :pro

  describe "all_rules/1" do
    test "returning configured rules in evaluation order" do
      conf =
        start_pruner!(
          rules: [
            [name: "default", max_age: {1, :day}],
            [name: "media", queue: "media", max_len: 500],
            [name: "audit", worker: "MyApp.Audit", max_age: :infinity]
          ]
        )

      assert ["media", "audit", "default"] = Enum.map(PrunerQuery.all_rules(conf), & &1.name)
    end

    test "returning rules with match and mode details" do
      conf =
        start_pruner!(rules: [[name: "media", queue: "media", state: :completed, max_len: 500]])

      assert [rule, _default] = PrunerQuery.all_rules(conf)

      assert %{queue: "media", state: "completed", worker: nil} = rule.match
      assert %{kind: :max_len, value: "500"} = rule.mode
    end

    test "degrading without a pruners table" do
      conf = Config.new(repo: Oban.Web.SQLiteRepo, engine: Oban.Engines.Lite)

      assert [] = PrunerQuery.all_rules(conf)
    end
  end

  describe "display_rules/2" do
    setup do
      conf =
        start_pruner!(
          rules: [
            [name: "media", queue: "media", max_len: 500, limit: 1_000],
            [name: "audit", worker: "MyApp.Audit", max_age: :infinity, archive: true],
            [name: "failures", state: :discarded, max_age: {10, :minutes}, paused: true],
            [name: "default", max_age: {1, :day}]
          ]
        )

      {:ok, rules: PrunerQuery.all_rules(conf)}
    end

    test "keeping the evaluation chain without params", %{rules: rules} do
      assert ~w(media audit failures default) = names(rules, %{})
    end

    test "filtering rules by name", %{rules: rules} do
      assert ~w(media) = names(rules, %{names: ~w(media)})
      assert ~w(media failures) = names(rules, %{names: ~w(media failures)})
      assert [] = names(rules, %{names: ~w(missing)})
    end

    test "filtering rules by what they match", %{rules: rules} do
      assert ~w(media) = names(rules, %{queues: ~w(media)})
      assert ~w(audit) = names(rules, %{workers: ~w(MyApp.Audit)})
      assert ~w(failures) = names(rules, %{states: ~w(discarded)})
      assert [] = names(rules, %{queues: ~w(media), states: ~w(discarded)})
    end

    test "filtering rules by retention mode", %{rules: rules} do
      assert ~w(media) = names(rules, %{modes: ~w(length)})
      assert ~w(audit failures default) = names(rules, %{modes: ~w(age)})
    end

    test "filtering rules by status", %{rules: rules} do
      assert ~w(failures) = names(rules, %{stats: ~w(paused)})
      assert ~w(media audit default) = names(rules, %{stats: ~w(active)})
      assert ~w(audit) = names(rules, %{stats: ~w(archiving)})
      assert ~w(audit failures) = names(rules, %{stats: ~w(archiving paused)})
    end

    test "sorting rules by name", %{rules: rules} do
      assert ~w(audit default failures media) = names(rules, sort(%{}, "name", "asc"))
      assert ~w(media failures default audit) = names(rules, sort(%{}, "name", "desc"))
    end

    test "sorting rules by limit", %{rules: rules} do
      assert ["media" | _rest] = names(rules, sort(%{}, "limit", "asc"))
    end

    test "sorting rules by retention, with unbounded rules last", %{rules: rules} do
      assert ~w(failures default audit media) = names(rules, sort(%{}, "retention", "asc"))
    end

    test "reversing the evaluation chain", %{rules: rules} do
      assert ~w(default failures audit media) = names(rules, sort(%{}, "order", "desc"))
    end

    test "sorting filtered rules", %{rules: rules} do
      params = sort(%{modes: ~w(age)}, "name", "asc")

      assert ~w(audit default failures) = names(rules, params)
    end

    defp names(rules, params) do
      rules
      |> PrunerQuery.display_rules(params)
      |> Enum.map(& &1.name)
    end

    defp sort(params, sort_by, sort_dir) do
      Map.merge(params, %{sort_by: sort_by, sort_dir: sort_dir})
    end
  end

  describe "suggest/2" do
    test "suggesting qualifiers without any terms" do
      conf = start_pruner!(rules: [[name: "media", queue: "media", max_len: 500]])

      assert [{"names:", _, _} | _rest] = PrunerQuery.suggest("", conf)
      assert [{"stats:", _, _}] = PrunerQuery.suggest("stats", conf)
    end

    test "suggesting values from persisted rules" do
      conf =
        start_pruner!(
          rules: [
            [name: "media", queue: "media", max_len: 500],
            [name: "audit", worker: "MyApp.Audit", max_age: :infinity]
          ]
        )

      assert [{"media", _, _} | _rest] = PrunerQuery.suggest("names:med", conf)
      assert [{"media", _, _}] = PrunerQuery.suggest("queues:", conf)
      assert [{"MyApp.Audit", _, _}] = PrunerQuery.suggest("workers:Audit", conf)
    end

    test "suggesting static values for modes, states, and stats" do
      conf = start_pruner!(rules: [[name: "media", queue: "media", max_len: 500]])

      assert [{"age", _, _}] = PrunerQuery.suggest("modes:a", conf)
      assert [{"discarded", _, _}] = PrunerQuery.suggest("states:dis", conf)
      assert [{"paused", _, _}] = PrunerQuery.suggest("stats:pau", conf)
    end
  end

  describe "configured_names/1" do
    test "naming rules declared in the configuration" do
      conf = start_pruner!(rules: [[name: "media", queue: "media", max_len: 500]])

      assert {:ok, _rule} = Pruner.insert(conf.name, name: "runtime", max_len: 100)

      names = PrunerQuery.configured_names(conf)

      assert MapSet.member?(names, "media")
      refute MapSet.member?(names, "runtime")
      refute MapSet.member?(names, "default")
    end

    test "naming rules generated from legacy configuration" do
      conf =
        start_pruner!(
          mode: {:max_age, {1, :day}},
          queue_overrides: [media: {:max_len, 500}],
          state_overrides: [discarded: {:max_age, {7, :days}}]
        )

      names = PrunerQuery.configured_names(conf)

      assert MapSet.member?(names, "queue-media")
      assert MapSet.member?(names, "state-discarded")
      assert MapSet.member?(names, "default")
    end

    test "ignoring instances without a pruner" do
      conf = Config.new(repo: Oban.Web.Repo, plugins: [])

      assert MapSet.new() == PrunerQuery.configured_names(conf)
    end
  end

  defp start_pruner!(opts) do
    name = start_supervised_oban!(engine: Oban.Pro.Engine, plugins: [{Pruner, opts}])

    name
    |> Oban.Registry.whereis({:plugin, Pruner})
    |> :sys.get_state()

    Oban.config(name)
  end
end
