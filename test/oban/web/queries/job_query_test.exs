defmodule Oban.Web.JobQueryTest do
  use Oban.Web.Case, async: true

  alias Oban.Config
  alias Oban.Web.{JobQuery, Repo}

  @conf Config.new(repo: Repo)

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
  end

  describe "suggest/2" do
    def suggest(terms), do: JobQuery.suggest(terms, @conf)

    def sorted_suggest(terms) do
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

    test "suggesting args paths" do
      assert [] = suggest("args:")
      assert [] = suggest("args.")
      assert [] = suggest("args.id")

      insert_job!(%{id: 1, account_id: 1})
      insert_job!(%{id: 1, name: "Alpha"})
      insert_job!(%{id: 1, data: %{on: true}})

      assert ~w(account_id: data. id: name:) =
               "args."
               |> suggest()
               |> Enum.map(&elem(&1, 0))
               |> Enum.sort()

      assert [] = suggest("args.name.")
      assert [{"account_id:", _, _}] = suggest("args.accou")
      assert [{"on:", _, _}] = suggest("args.data.")
    end

    test "suggesting nested args" do
      insert_job!(%{id: 1, add: %{city: %{name: "Chi", zip: "60647"}, state: "IL"}})
      insert_job!(%{xd: 2, add: %{city: %{name: "Whe", zip: "60187"}, state: "IL"}})

      assert ~w(city. state:) = sorted_suggest("args.add.")

      assert [{"state:", _, _}] = suggest("args.add.stat")
      assert [{"name:", _, _}] = suggest("args.add.city.nam")
    end

    test "suggesting nested args values" do
      insert_job!(%{id: 1, account_id: 1})
      insert_job!(%{id: 2, account_id: 2, name: "Alpha Mode"})
      insert_job!(%{id: 3, name: "Delta Mode"})

      assert [] = suggest("args:")
      assert [] = suggest("args.:")
      assert [] = sorted_suggest("args.missing:")
      assert ~w(1 2 3) = sorted_suggest("args.id:")
      assert ~w(1 2) = sorted_suggest("args.account_id:")
      assert ["Alpha Mode", "Delta Mode"] = sorted_suggest("args.name:")
    end

    test "suggesting meta paths" do
      insert_job!(%{}, meta: %{id: 1, account_id: 1})
      insert_job!(%{}, meta: %{id: 1, name: "Alpha"})
      insert_job!(%{}, meta: %{id: 1, return: "recorded-stuff"})

      assert ~w(account_id: id: name:) =
               "meta."
               |> suggest()
               |> Enum.map(&elem(&1, 0))
               |> Enum.sort()

      assert [{"account_id:", _, _}] = suggest("meta.accou")
    end

    test "suggesting nodes" do
      assert [] = suggest("nodes:")

      insert_job!(%{}, state: "executing", attempted_by: ["web.1@host", "abc-123"])
      insert_job!(%{}, state: "executing", attempted_by: ["web.2@host", "abc-123"])
      insert_job!(%{}, state: "executing", attempted_by: ["loc.8@host", "abc-123"])

      assert [{"loc.8@host", _, _}, _, _] = suggest("nodes:")
      assert [{"web.1@host", _, _}, {"web.2@host", _, _}] = suggest("nodes:web")
      assert [{"web.1@host", _, _}, _] = suggest("nodes:web.1")
    end

    test "suggesting queues" do
      assert [] = suggest("queues:")

      insert_job!(%{}, queue: "alpha")
      insert_job!(%{}, queue: "gamma")
      insert_job!(%{}, queue: "delta")

      assert [{"alpha", _, _}, _, _] = suggest("queues:")
      assert [{"alpha", _, _}] = suggest("queues:alph")
      assert [{"delta", _, _}, _] = suggest("queues:delta")
    end

    test "suggesting tags" do
      assert [] = suggest("tags:")

      insert_job!(%{}, tags: ~w(alpha gamma))
      insert_job!(%{}, tags: ~w(gamma delta))
      insert_job!(%{}, tags: ~w(delta))

      assert ~w(alpha delta gamma) =
               "tags:"
               |> suggest()
               |> Enum.map(&elem(&1, 0))
               |> Enum.sort()

      assert [{"delta", _, _}] = suggest("tags:de")
    end

    test "suggesting workers" do
      assert [] = suggest("workers:")

      insert_job!(%{}, worker: MyApp.Alpha)
      insert_job!(%{}, worker: MyApp.Gamma)
      insert_job!(%{}, worker: MyApp.Delta)

      assert [{"MyApp.Alpha", _, _}, _, _] = suggest("workers:")
      assert [{"MyApp.Alpha", _, _}, _, _] = suggest("workers:My")
      assert [{"MyApp.Delta", _, _}] = suggest("workers:Delta")
    end

    test "suggesting with a resolver that implements hint_query_limit/1" do
      defmodule HintResolver do
        def hint_query_limit(:workers), do: 1
        def hint_query_limit(_qualifier), do: :infinity
      end

      insert_job!(%{}, queue: :alpha, worker: MyApp.Alpha)
      insert_job!(%{}, queue: :gamma, worker: MyApp.Gamma)
      insert_job!(%{}, queue: :delta, worker: MyApp.Delta)

      assert [_, _] = JobQuery.suggest("workers:", @conf, resolver: HintResolver)
      assert [_, _, _] = JobQuery.suggest("queues:", @conf, resolver: HintResolver)
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

    test "completing a path qualifier" do
      insert_job!(%{id: 1, account_id: 1})

      assert "args.id:" == complete("args.i")
      assert "args.account_id:" == complete("args.accou")
    end

    test "completing a qualifier with a partial path" do
      insert_job!(%{}, worker: "MyApp.Alpha")

      assert "workers:MyApp.Alpha" == complete("workers:My")
      assert "workers:MyApp.Alpha" == complete("workers:MyApp.A")
    end
  end

  defp conf(repo) do
    engine =
      case repo do
        Oban.Web.Repo -> Oban.Engines.Basic
        Oban.Web.LiteRepo -> Oban.Engines.Lite
        Oban.Web.DolphinRepo -> Oban.Engines.Dolphin
      end

    Config.new(repo: repo, engine: engine)
  end

  for repo <- [Oban.Web.Repo, Oban.Web.LiteRepo, Oban.Web.DolphinRepo] do
    describe "all_jobs/2 with #{inspect(repo)}" do
      @repo repo

      @describetag dolphin: repo == Oban.Web.DolphinRepo
      @describetag lite: repo == Oban.Web.LiteRepo

      test "filtering by id using" do
        conf = conf(@repo)

        job_1 = insert_job!(%{ref: 1}, conf: conf)
        job_2 = insert_job!(%{ref: 2}, conf: conf)
        job_3 = insert_job!(%{ref: 3}, conf: conf)

        assert [1] = filter_refs(conf, ids: ~w(#{job_1.id}))
        assert [1, 2] = filter_refs(conf, ids: ~w(#{job_1.id} #{job_2.id}))
        assert [1, 3] = filter_refs(conf, ids: ~w(#{job_1.id} #{job_3.id}))
        assert [] = filter_refs(conf, ids: ~w(12345))
      end

      test "filtering by node" do
        conf = conf(@repo)

        insert_job!(%{ref: 1}, attempted_by: ["worker.1", "abc-123"], conf: conf)
        insert_job!(%{ref: 2}, attempted_by: ["worker.2", "abc-123"], conf: conf)

        assert [1] = filter_refs(conf, nodes: ~w(worker.1))
        assert [2] = filter_refs(conf, nodes: ~w(worker.2))
        assert [1, 2] = filter_refs(conf, nodes: ~w(worker.1 worker.2))
        assert [] = filter_refs(conf, nodes: ~w(web.1))
      end

      test "filtering by priority" do
        conf = conf(@repo)

        insert_job!(%{ref: 0}, priority: 0, conf: conf)
        insert_job!(%{ref: 1}, priority: 1, conf: conf)
        insert_job!(%{ref: 2}, priority: 2, conf: conf)

        assert [0] = filter_refs(conf, priorities: ~w(0))
        assert [0, 1] = filter_refs(conf, priorities: ~w(0 1))
        assert [0, 1, 2] = filter_refs(conf, priorities: ~w(0 1 2 3))
        assert [] = filter_refs(conf, priorities: ~w(3))
      end

      test "filtering by queue" do
        conf = conf(@repo)

        insert_job!(%{ref: 1}, queue: "alpha", conf: conf)
        insert_job!(%{ref: 2}, queue: "gamma", conf: conf)

        assert [1] = filter_refs(conf, queues: ~w(alpha))
        assert [2] = filter_refs(conf, queues: ~w(gamma))
        assert [1, 2] = filter_refs(conf, queues: ~w(alpha gamma))
        assert [] = filter_refs(conf, queues: ~w(delta))
      end

      test "filtering by state" do
        conf = conf(@repo)

        insert_job!(%{ref: 0}, state: "available", conf: conf)
        insert_job!(%{ref: 1}, state: "available", conf: conf)
        insert_job!(%{ref: 2}, state: "scheduled", conf: conf)
        insert_job!(%{ref: 3}, state: "completed", conf: conf)

        assert [0, 1] = filter_refs(conf, state: "available")
        assert [] = filter_refs(conf, state: "executing")
      end

      test "filtering by tags" do
        conf = conf(@repo)

        insert_job!(%{ref: 0}, tags: ["audio"], conf: conf)
        insert_job!(%{ref: 1}, tags: ["audio", "video"], conf: conf)
        insert_job!(%{ref: 2}, tags: ["video"], conf: conf)

        assert [0, 1] = filter_refs(conf, tags: ~w(audio))
        assert [1, 2] = filter_refs(conf, tags: ~w(video))
        assert [0, 1, 2] = filter_refs(conf, tags: ~w(audio video))
        assert [0, 1] = filter_refs(conf, tags: ~w(audio nada))
        assert [] = filter_refs(conf, tags: ~w(nada))
      end

      test "filtering by worker" do
        conf = conf(@repo)

        insert_job!(%{ref: 1}, worker: MyApp.VideoA, conf: conf)
        insert_job!(%{ref: 2}, worker: MyApp.VideoB, conf: conf)

        assert [1] = filter_refs(conf, workers: ~w(MyApp.VideoA))
        assert [2] = filter_refs(conf, workers: ~w(MyApp.VideoB))
        assert [1, 2] = filter_refs(conf, workers: ~w(MyApp.VideoA MyApp.VideoB))
        assert [] = filter_refs(conf, workers: ~w(MyApp.Video))
      end

      test "searching within args sub-fields" do
        conf = conf(@repo)

        insert_job!(%{ref: 0, mode: "audio", bar: %{baz: 1}}, conf: conf)
        insert_job!(%{ref: 1, mode: "video", bar: %{baz: 2}}, conf: conf)
        insert_job!(%{ref: 2, mode: "media", bar: %{bat: 3}}, conf: conf)

        assert [0] = filter_refs(conf, args: [~w(mode), "audio"])
        assert [1] = filter_refs(conf, args: [~w(mode), "video"])

        assert [0] = filter_refs(conf, args: [~w(bar baz), "1"])
        assert [2] = filter_refs(conf, args: [~w(bar bat), "3"])
        assert [] = filter_refs(conf, args: [~w(bar bat), "4"])
      end

      test "searching within meta sub-fields" do
        conf = conf(@repo)

        insert_job!(%{ref: 0}, meta: %{mode: "audio", bar: %{baz: "21f8"}}, conf: conf)
        insert_job!(%{ref: 1}, meta: %{mode: "video", bar: %{baz: 7050}}, conf: conf)
        insert_job!(%{ref: 2}, meta: %{mode: "media", bar: %{bat: "4b0e"}}, conf: conf)

        assert [0] = filter_refs(conf, meta: [~w(mode), "audio"])
        assert [2] = filter_refs(conf, meta: [~w(bar bat), "4b0e"])
        assert [0] = filter_refs(conf, meta: [~w(bar baz), "21f8"])
        assert [1] = filter_refs(conf, meta: [~w(bar baz), "7050"])
      end

      test "filtering by multiple terms" do
        conf = conf(@repo)

        insert_job!(%{ref: 0, mode: "video"}, worker: Media, meta: %{batch_id: 1}, conf: conf)
        insert_job!(%{ref: 1, mode: "audio"}, worker: Media, meta: %{batch_id: 1}, conf: conf)
        insert_job!(%{ref: 2, mode: "multi"}, worker: Media, meta: %{batch_id: 2}, conf: conf)

        assert [0, 1] = filter_refs(conf, workers: ~w(Media), meta: [~w(batch_id), "1"])
        assert [2] = filter_refs(conf, args: [~w(mode), "multi"], meta: [~w(batch_id), "2"])
      end

      test "ordering jobs by state" do
        conf = conf(@repo)
        ago = fn sec -> DateTime.add(DateTime.utc_now(), -sec) end

        job_a = insert_job!(%{}, state: "cancelled", cancelled_at: ago.(4), conf: conf)
        job_b = insert_job!(%{}, state: "cancelled", cancelled_at: ago.(6), conf: conf)
        job_c = insert_job!(%{}, state: "cancelled", cancelled_at: ago.(1), conf: conf)

        assert [job_c.id, job_a.id, job_b.id] ==
                 %{state: "cancelled"}
                 |> JobQuery.all_jobs(conf)
                 |> Enum.map(& &1.id)

        assert [job_b.id, job_a.id, job_c.id] ==
                 %{state: "cancelled", sort_dir: "desc"}
                 |> JobQuery.all_jobs(conf)
                 |> Enum.map(& &1.id)
      end

      test "restrict the query with a resolver that implements jobs_query_limit/1" do
        conf = conf(@repo)

        insert_job!(%{ref: 0}, state: "executing", conf: conf)
        insert_job!(%{ref: 1}, state: "executing", conf: conf)
        insert_job!(%{ref: 2}, state: "executing", conf: conf)
        insert_job!(%{ref: 3}, state: "completed", conf: conf)
        insert_job!(%{ref: 4}, state: "completed", conf: conf)
        insert_job!(%{ref: 5}, state: "completed", conf: conf)

        assert [0, 1, 2] = filter_refs(conf, %{state: "executing"}, resolver: JobResolver)
        assert [4, 5] = filter_refs(conf, %{state: "completed"}, resolver: JobResolver)
      end
    end
  end

  describe "all_job_ids/3" do
    test "returning all ids within the current filters" do
      job_1 = insert_job!(%{ref: 1}, worker: MyApp.VideoA)
      job_2 = insert_job!(%{ref: 2}, worker: MyApp.VideoB)
      job_3 = insert_job!(%{ref: 3}, worker: MyApp.VideoB)

      all_job_ids = fn params, opts ->
        params
        |> Map.put_new(:state, "available")
        |> JobQuery.all_job_ids(@conf, opts)
      end

      assert [job_1.id, job_2.id, job_3.id] == all_job_ids.(%{}, [])
      assert [job_2.id, job_3.id] == all_job_ids.(%{workers: ~w(MyApp.VideoB)}, [])
    end
  end

  defp filter_refs(conf, params) when is_struct(conf, Config) do
    filter_refs(conf, params, [])
  end

  defp filter_refs(params, opts) do
    filter_refs(@conf, params, opts)
  end

  defp filter_refs(conf, params, opts) do
    params =
      params
      |> Map.new()
      |> Map.put_new(:state, "available")

    params
    |> JobQuery.all_jobs(conf, opts)
    |> Enum.map(& &1.args["ref"])
    |> Enum.sort()
  end
end
