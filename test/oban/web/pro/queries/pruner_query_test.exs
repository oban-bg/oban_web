if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.PrunerQueryTest do
    # Pruner rules are keyed by name and the plugin always inserts the default rule on start.
    # Inserts of the same key from concurrent sandbox transactions block until the other test
    # finishes, so the pruner modules run serially with each other while still running
    # concurrently with everything else.
    use Oban.Web.ProCase, async: true, group: :pruners

    alias Oban.Config
    alias Oban.Pro.Pruner
    alias Oban.Web.PrunerQuery

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

    describe "create_rule/2" do
      setup :start_rules

      test "appending new rules ahead of the default", %{conf: conf} do
        params = %{
          name: "audit",
          match: %{worker: "MyApp.Audit", state: "completed"},
          mode: %{kind: :max_age, value: "2 weeks"},
          limit: 500
        }

        assert {:ok, rule} = PrunerQuery.create_rule(conf, params)

        assert %{name: "audit", position: 2, limit: 500, paused: false} = rule
        assert %{worker: "MyApp.Audit", state: "completed", queue: nil} = rule.match
        assert %{kind: :max_age, value: "2 weeks"} = rule.mode

        assert {:error, message} = PrunerQuery.create_rule(conf, %{params | name: "media"})
        assert message =~ "already exists"

        assert {:error, changeset} =
                 PrunerQuery.create_rule(conf, %{params | name: "huge", limit: 20_000_000})

        assert %{limit: _} = Map.new(changeset.errors)

        assert ~w(media events audit default) == rule_names(conf)
        assert %{mode: %{value: "500"}} = find_rule(conf, "media")
      end
    end

    describe "update_rule/4" do
      setup :start_rules

      test "changing a rule unless it's stale or missing", %{conf: conf} do
        %{lock_version: lock_version} = rule = find_rule(conf, "media")

        params = %{
          match: %{queue: nil, state: "discarded"},
          mode: %{kind: :max_age, value: "infinity"}
        }

        assert {:ok, updated} = PrunerQuery.update_rule(conf, "media", lock_version, params)

        assert %{queue: nil, state: "discarded"} = updated.match
        assert %{kind: :max_age, value: "infinity"} = updated.mode
        assert updated.lock_version == lock_version + 1

        assert {:error, changeset} =
                 PrunerQuery.update_rule(conf, "media", lock_version, %{limit: 20})

        assert %{lock_version: _} = Map.new(changeset.errors)
        assert {:error, %Ecto.Changeset{}} = PrunerQuery.toggle_rule(conf, rule, true)

        assert {:ok, %{paused: true, limit: 10_000}} =
                 PrunerQuery.toggle_rule(conf, updated, true)

        assert {:error, :not_found} = PrunerQuery.update_rule(conf, "missing", 1, %{limit: 20})
      end
    end

    describe "delete_rule/2" do
      setup :start_rules

      test "deleting a rule unless it's the default, stale, or missing", %{conf: conf} do
        rule = find_rule(conf, "media")

        assert {:error, message} = PrunerQuery.delete_rule(conf, find_rule(conf, "default"))
        assert message =~ "can't be deleted"

        assert {:error, :not_found} = PrunerQuery.delete_rule(conf, %{rule | name: "missing"})

        assert {:ok, paused} = PrunerQuery.toggle_rule(conf, rule, true)
        assert {:error, %Ecto.Changeset{}} = PrunerQuery.delete_rule(conf, rule)
        assert ~w(media events default) == rule_names(conf)

        assert {:ok, _rule} = PrunerQuery.delete_rule(conf, paused)
        assert ~w(events default) == rule_names(conf)
      end
    end

    describe "move_rule/3" do
      setup :start_rules

      test "moving a rule within the chain while the default stays last", %{conf: conf} do
        assert {:ok, %{position: 0}} = PrunerQuery.move_rule(conf, find_rule(conf, "events"), 0)
        assert ~w(events media default) == rule_names(conf)

        assert {:ok, %{position: 1}} = PrunerQuery.move_rule(conf, find_rule(conf, "events"), 9)
        assert {:ok, _rule} = PrunerQuery.move_rule(conf, find_rule(conf, "default"), 0)
        assert ~w(media events default) == rule_names(conf)
        assert [0, 1, 2] == Enum.map(PrunerQuery.all_rules(conf), & &1.position)

        missing = %{find_rule(conf, "media") | name: "missing"}

        assert {:error, :not_found} = PrunerQuery.move_rule(conf, missing, 0)
      end
    end

    defp start_rules(_context) do
      conf =
        start_pruner!(
          rules: [
            [name: "media", queue: "media", max_len: 500],
            [name: "events", queue: "events", max_age: {1, :day}],
            [name: "default", max_age: {7, :days}]
          ]
        )

      {:ok, conf: conf}
    end

    defp rule_names(conf), do: Enum.map(PrunerQuery.all_rules(conf), & &1.name)

    defp find_rule(conf, name), do: Enum.find(PrunerQuery.all_rules(conf), &(&1.name == name))

    defp start_pruner!(opts) do
      name = start_supervised_oban!(plugins: [{Pruner, opts}])

      name
      |> Oban.Registry.whereis({:plugin, Pruner})
      |> :sys.get_state()

      Oban.config(name)
    end
  end
end
