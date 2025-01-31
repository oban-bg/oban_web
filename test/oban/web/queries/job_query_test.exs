for repo <- [Oban.Web.Repo, Oban.Web.SQLiteRepo, Oban.Web.MyXQLRepo] do
  defmodule Module.concat(repo, JobQueryTest) do
    use Oban.Web.Case, async: true

    alias Oban.Config
    alias Oban.Web.JobQuery

    @repo repo

    @engine (case repo do
               Oban.Web.MyXQLRepo -> Oban.Engines.Dolphin
               Oban.Web.Repo -> Oban.Engines.Basic
               Oban.Web.SQLiteRepo -> Oban.Engines.Lite
             end)

    @conf Config.new(repo: @repo, engine: @engine)

    @moduletag myxql: repo == Oban.Web.MyXQLRepo
    @moduletag sqlite: repo == Oban.Web.SQLiteRepo

    defmodule HintResolver do
      def hint_query_limit(:workers), do: 1
      def hint_query_limit(_qualifier), do: :infinity
    end

    defmodule JobResolver do
      def jobs_query_limit(:completed), do: 1
      def jobs_query_limit(:executing), do: 10
    end

    describe "parse/1" do
      import JobQuery, only: [parse: 1]

      test "splitting multiple values" do
        assert %{nodes: ["worker-1"]} = parse("nodes:worker-1")
        assert %{queues: ["alpha", "gamma"]} = parse("queues:alpha,gamma")
        assert %{workers: ["My.A", "My.B"]} = parse("workers:My.A,My.B")
        assert %{tags: ["alpha", "gamma"]} = parse("tags:alpha,gamma")
      end

      test "splitting path qualifiers" do
        assert %{args: [~w(account), ""]} = parse("args.account")
        assert %{args: [~w(account), "Foo"]} = parse("args.account:Foo")
        assert %{args: [~w(account name), "Foo"]} = parse("args.account.name:Foo")
      end

      test "retaining surrounding quotes" do
        assert %{args: ~s("Foo")} = parse(~s(args:"Foo"))
        assert %{meta: ~s("Foo")} = parse(~s(meta:"Foo"))
        assert %{args: [~w(account), ~s("Foo")]} = parse(~s(args.account:"Foo"))
        assert %{meta: [~w(account), ~s("Foo")]} = parse(~s(meta.account:"Foo"))
      end
    end

    describe "complete/2" do
      def complete(terms) do
        JobQuery.complete(terms, @conf)
      end

      test "completing with an unknown qualifier" do
        assert "stuff" == complete("stuff")
      end

      test "completing a qualifier" do
        assert "queues:" == complete("qu")
        assert "queues:" == complete("queue")
      end

      @tag skip: repo == Oban.Web.MyXQLRepo
      test "completing a path qualifier" do
        insert!(%{id: 1, account_id: 1})

        assert "args.id:" == complete("args.i")
        assert "args.account_id:" == complete("args.accou")
      end

      test "completing a qualifier with a partial path" do
        insert!(%{}, worker: "MyApp.Alpha")

        assert "workers:MyApp.Alpha" == complete("workers:My")
        assert "workers:MyApp.Alpha" == complete("workers:MyApp.A")
      end
    end

    describe "suggest/2 with #{inspect(repo)}" do
      defp suggest(terms, opts \\ []) do
        JobQuery.suggest(terms, @conf, opts)
      end

      defp sorted_suggest(terms) do
        terms
        |> JobQuery.suggest(@conf)
        |> Enum.map(&elem(&1, 0))
        |> Enum.sort()
      end

      test "falling back to defaults without a query" do
        assert [{"args.", _, _} | _] = suggest("")
        assert [{"args.", _, _} | _] = suggest("  ")
      end

      test "falling back to defaults without any fragments" do
        assert [{"args.", _, _} | _] = suggest("priority:1 ")
      end

      test "suggesting qualifiers with fragments" do
        assert [{"priorities:", _, _}] = suggest("prior")
        assert [{"priorities:", _, _}] = suggest("priorities")
      end

      test "ignoring unsuggestable qualifiers" do
        assert [] = suggest("args:")
        assert [] = suggest("args.id:")
        assert [] = suggest("meta:")
        assert [] = suggest("meta.batch_id:")
      end

      test "suggesting fixed priorities" do
        assert [{"0", _, _} | _] = suggest("priorities:")
        assert [{"0", _, _}] = suggest("priorities:0")
        assert [{"1", _, _}] = suggest("priorities:1")
      end

      @tag skip: repo == Oban.Web.MyXQLRepo
      test "suggesting args paths" do
        assert [] = suggest("args:")
        assert [] = suggest("args.")
        assert [] = suggest("args.id")

        insert!(%{id: 1, account_id: 1})
        insert!(%{id: 2, name: "Alpha"})
        insert!(%{id: 3, name: "Gamma"})
        insert!(%{id: 4, data: %{on: true}})

        assert ~w(account_id: data. id: name:) =
                 "args."
                 |> suggest()
                 |> Enum.map(&elem(&1, 0))
                 |> Enum.sort()

        assert [] = suggest("args.name.")
        assert [{"account_id:", _, _}] = suggest("args.accou")
        assert [{"on:", _, _}] = suggest("args.data.")
      end

      @tag skip: repo == Oban.Web.MyXQLRepo
      test "suggesting nested args" do
        insert!(%{id: 1, add: %{city: %{name: "Chi"}, state: "IL"}})
        insert!(%{xd: 2, add: %{city: %{name: "Whe"}, state: "IL"}})

        assert ~w(city. state:) = sorted_suggest("args.add.")

        assert [{"state:", _, _}] = suggest("args.add.stat")
        assert [{"name:", _, _}] = suggest("args.add.city.nam")
      end

      @tag skip: repo == Oban.Web.MyXQLRepo
      test "suggesting nested args values" do
        insert!(%{id: 1, account_id: 1})
        insert!(%{id: 2, account_id: 2, name: "Alpha Mode"})
        insert!(%{id: 3, name: "Delta Mode"})

        assert [] = suggest("args:")
        assert [] = suggest("args.:")
        assert [] = suggest("args.missing:")
        assert ~w(1 2 3) = sorted_suggest("args.id:")
        assert ~w(1 2) = sorted_suggest("args.account_id:")
        assert ["Alpha Mode", "Delta Mode"] = sorted_suggest("args.name:")
      end

      @tag skip: repo == Oban.Web.MyXQLRepo
      test "suggesting meta paths" do
        insert!(%{}, meta: %{id: 1, account_id: 1})
        insert!(%{}, meta: %{id: 1, name: "Alpha"})
        insert!(%{}, meta: %{id: 1, return: "recorded-stuff"})

        assert ~w(account_id: id: name:) =
                 "meta."
                 |> suggest()
                 |> Enum.map(&elem(&1, 0))
                 |> Enum.sort()

        assert [{"account_id:", _, _}] = suggest("meta.accou")
      end

      test "suggesting nodes" do
        assert [] = suggest("nodes:")

        insert!(%{}, state: "executing", attempted_by: ["web.1@host", "abc-123"])
        insert!(%{}, state: "executing", attempted_by: ["web.2@host", "abc-123"])
        insert!(%{}, state: "executing", attempted_by: ["loc.8@host", "abc-123"])

        assert [{"loc.8@host", _, _}, _, _] = suggest("nodes:")
        assert [{"web.1@host", _, _}, {"web.2@host", _, _}] = suggest("nodes:web")
        assert [{"web.1@host", _, _}, _] = suggest("nodes:web.1")
      end

      test "suggesting queues" do
        assert [] = suggest("queues:")

        insert!(%{}, queue: "alpha")
        insert!(%{}, queue: "gamma")
        insert!(%{}, queue: "delta")

        assert [{"alpha", _, _}, _, _] = suggest("queues:")
        assert [{"alpha", _, _}] = suggest("queues:alph")
        assert [{"delta", _, _}, _] = suggest("queues:delta")
      end

      test "suggesting tags" do
        assert [] = suggest("tags:")

        insert!(%{}, tags: ~w(alpha gamma))
        insert!(%{}, tags: ~w(gamma delta))
        insert!(%{}, tags: ~w(delta))

        assert ~w(alpha delta gamma) =
                 "tags:"
                 |> suggest()
                 |> Enum.map(&elem(&1, 0))
                 |> Enum.sort()

        assert [{"delta", _, _}] = suggest("tags:de")
      end

      test "suggesting workers" do
        assert [] = suggest("workers:")

        insert!(%{}, worker: MyApp.Alpha)
        insert!(%{}, worker: MyApp.Gamma)
        insert!(%{}, worker: MyApp.Delta)

        assert [{"MyApp.Alpha", _, _}, _, _] = suggest("workers:")
        assert [{"MyApp.Alpha", _, _}, _, _] = suggest("workers:My")
        assert [{"MyApp.Delta", _, _}] = suggest("workers:Delta")
      end

      test "suggesting with custom resolver" do
        insert!(%{}, queue: :alpha, worker: MyApp.Alpha)
        insert!(%{}, queue: :gamma, worker: MyApp.Gamma)
        insert!(%{}, queue: :delta, worker: MyApp.Delta)

        assert [_, _] = suggest("workers:", resolver: HintResolver)
        assert [_, _, _] = suggest("queues:", resolver: HintResolver)
      end
    end

    describe "all_jobs/2" do
      defp filter_refs(params, opts \\ []) do
        params =
          params
          |> Map.new()
          |> Map.put_new(:state, "available")

        params
        |> JobQuery.all_jobs(@conf, opts)
        |> Enum.map(& &1.args["ref"])
        |> Enum.sort()
      end

      test "filtering by id using" do
        job_1 = insert!(%{ref: 1})
        job_2 = insert!(%{ref: 2})
        job_3 = insert!(%{ref: 3})

        assert [1] = filter_refs(ids: ~w(#{job_1.id}))
        assert [1, 2] = filter_refs(ids: ~w(#{job_1.id} #{job_2.id}))
        assert [1, 3] = filter_refs(ids: ~w(#{job_1.id} #{job_3.id}))
        assert [] = filter_refs(ids: ~w(12345))
      end

      test "filtering by node" do
        insert!(%{ref: 1}, attempted_by: ["worker.1", "abc-123"])
        insert!(%{ref: 2}, attempted_by: ["worker.2", "abc-123"])

        assert [1] = filter_refs(nodes: ~w(worker.1))
        assert [2] = filter_refs(nodes: ~w(worker.2))
        assert [1, 2] = filter_refs(nodes: ~w(worker.1 worker.2))
        assert [] = filter_refs(nodes: ~w(web.1))
      end

      test "filtering by priority" do
        insert!(%{ref: 0}, priority: 0)
        insert!(%{ref: 1}, priority: 1)
        insert!(%{ref: 2}, priority: 2)

        assert [0] = filter_refs(priorities: ~w(0))
        assert [0, 1] = filter_refs(priorities: ~w(0 1))
        assert [0, 1, 2] = filter_refs(priorities: ~w(0 1 2 3))
        assert [] = filter_refs(priorities: ~w(3))
      end

      test "filtering by queue" do
        insert!(%{ref: 1}, queue: "alpha")
        insert!(%{ref: 2}, queue: "gamma")

        assert [1] = filter_refs(queues: ~w(alpha))
        assert [2] = filter_refs(queues: ~w(gamma))
        assert [1, 2] = filter_refs(queues: ~w(alpha gamma))
        assert [] = filter_refs(queues: ~w(delta))
      end

      test "filtering by state" do
        insert!(%{ref: 0}, state: "available")
        insert!(%{ref: 1}, state: "available")
        insert!(%{ref: 2}, state: "scheduled")
        insert!(%{ref: 3}, state: "completed")

        assert [0, 1] = filter_refs(state: "available")
        assert [] = filter_refs(state: "executing")
      end

      test "filtering by tags" do
        insert!(%{ref: 0}, tags: ["audio"])
        insert!(%{ref: 1}, tags: ["audio", "video"])
        insert!(%{ref: 2}, tags: ["video"])

        assert [0, 1] = filter_refs(tags: ~w(audio))
        assert [1, 2] = filter_refs(tags: ~w(video))
        assert [0, 1, 2] = filter_refs(tags: ~w(audio video))
        assert [0, 1] = filter_refs(tags: ~w(audio nada))
        assert [] = filter_refs(tags: ~w(nada))
      end

      test "filtering by worker" do
        insert!(%{ref: 1}, worker: MyApp.VideoA)
        insert!(%{ref: 2}, worker: MyApp.VideoB)

        assert [1] = filter_refs(workers: ~w(MyApp.VideoA))
        assert [2] = filter_refs(workers: ~w(MyApp.VideoB))
        assert [1, 2] = filter_refs(workers: ~w(MyApp.VideoA MyApp.VideoB))
        assert [] = filter_refs(workers: ~w(MyApp.Video))
      end

      test "searching within args sub-fields" do
        insert!(%{ref: 0, mode: "audio", bar: %{baz: 1}})
        insert!(%{ref: 1, mode: "video", bar: %{baz: 2}})
        insert!(%{ref: 2, mode: "media", bar: %{bat: 3}})

        assert [0] = filter_refs(args: [~w(mode), "audio"])
        assert [1] = filter_refs(args: [~w(mode), "video"])

        assert [0] = filter_refs(args: [~w(bar baz), "1"])
        assert [2] = filter_refs(args: [~w(bar bat), "3"])
        assert [] = filter_refs(args: [~w(bar bat), "4"])
      end

      test "searching within meta sub-fields" do
        insert!(%{ref: 0}, meta: %{mode: "audio", bar: %{baz: "21f8"}})
        insert!(%{ref: 1}, meta: %{mode: "video", bar: %{baz: 7050}})
        insert!(%{ref: 2}, meta: %{mode: "media", bar: %{bat: "4b0e"}})

        assert [0] = filter_refs(meta: [~w(mode), "audio"])
        assert [2] = filter_refs(meta: [~w(bar bat), "4b0e"])
        assert [0] = filter_refs(meta: [~w(bar baz), "21f8"])
        assert [1] = filter_refs(meta: [~w(bar baz), "7050"])
      end

      test "filtering by multiple terms" do
        insert!(%{ref: 0, mode: "video"}, worker: Media, meta: %{batch_id: 1})
        insert!(%{ref: 1, mode: "audio"}, worker: Media, meta: %{batch_id: 1})
        insert!(%{ref: 2, mode: "multi"}, worker: Media, meta: %{batch_id: 2})

        assert [0, 1] = filter_refs(workers: ~w(Media), meta: [~w(batch_id), "1"])
        assert [2] = filter_refs(args: [~w(mode), "multi"], meta: [~w(batch_id), "2"])
      end

      test "ordering jobs by state" do
        ago = fn sec -> DateTime.add(DateTime.utc_now(), -sec) end

        job_a = insert!(%{}, state: "cancelled", cancelled_at: ago.(4))
        job_b = insert!(%{}, state: "cancelled", cancelled_at: ago.(6))
        job_c = insert!(%{}, state: "cancelled", cancelled_at: ago.(1))

        assert [job_c.id, job_a.id, job_b.id] ==
                 %{state: "cancelled"}
                 |> JobQuery.all_jobs(@conf)
                 |> Enum.map(& &1.id)

        assert [job_b.id, job_a.id, job_c.id] ==
                 %{state: "cancelled", sort_dir: "desc"}
                 |> JobQuery.all_jobs(@conf)
                 |> Enum.map(& &1.id)
      end

      test "restrict the query with a resolver that implements jobs_query_limit/1" do
        insert!(%{ref: 0}, state: "executing")
        insert!(%{ref: 1}, state: "executing")
        insert!(%{ref: 2}, state: "executing")
        insert!(%{ref: 3}, state: "completed")
        insert!(%{ref: 4}, state: "completed")
        insert!(%{ref: 5}, state: "completed")

        assert [0, 1, 2] = filter_refs(%{state: "executing"}, resolver: JobResolver)
        assert [4, 5] = filter_refs(%{state: "completed"}, resolver: JobResolver)
      end
    end

    describe "all_job_ids/3" do
      test "returning all ids within the current filters" do
        job_1 = insert!(%{ref: 1}, worker: MyApp.VideoA)
        job_2 = insert!(%{ref: 2}, worker: MyApp.VideoB)
        job_3 = insert!(%{ref: 3}, worker: MyApp.VideoB)

        all_job_ids = fn params, opts ->
          params
          |> Map.put_new(:state, "available")
          |> JobQuery.all_job_ids(@conf, opts)
        end

        assert [job_1.id, job_2.id, job_3.id] == all_job_ids.(%{}, [])
        assert [job_2.id, job_3.id] == all_job_ids.(%{workers: ~w(MyApp.VideoB)}, [])
      end
    end

    defp insert!(args, opts \\ []) do
      opts = Keyword.put_new(opts, :conf, @conf)

      insert_job!(args, opts)
    end
  end
end
