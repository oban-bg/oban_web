defmodule Oban.Web.QueryTest do
  use Oban.Web.Case, async: true

  alias Oban.Config
  alias Oban.Web.{Query, Repo}

  @conf Config.new(repo: Repo)

  describe "parse/1" do
    import Query, only: [parse: 1]

    test "splitting multiple values" do
      assert %{nodes: ["worker-1"]} = parse("nodes:worker-1")
      assert %{queues: ["alpha", "gamma"]} = parse("queues:alpha,gamma")
      assert %{workers: ["My.A", "My.B"]} = parse("workers:My.A,My.B")
      assert %{tags: ["alpha", "gamma"]} = parse("tags:alpha,gamma")
    end

    test "splitting path qualifiers" do
      assert %{args: [~w(account), "Foo"]} = parse("args.account:Foo")
      assert %{args: [~w(account name), "Foo"]} = parse("args.account.name:Foo")
    end
  end

  describe "encode_params/1" do
    import Query, only: [encode_params: 1]

    test "encoding fields with multiple values" do
      assert [nodes: "web-1,web-2"] = encode_params(nodes: ~w(web-1 web-2))
    end

    test "encoding fields with path qualifiers" do
      assert [args: "a++x"] = encode_params(args: [~w(a), "x"])
      assert [args: "a,b++x"] = encode_params(args: [~w(a b), "x"])
      assert [args: "a,b,c++x"] = encode_params(args: [~w(a b c), "x"])
    end
  end

  describe "decode_params/1" do
    import Query, only: [decode_params: 1]

    test "decoding fields with known integers" do
      assert %{limit: 1} = decode_params(%{"limit" => "1"})
    end

    test "decoding params with multiple values" do
      assert %{nodes: ~w(web-1 web-2)} = decode_params(%{"nodes" => "web-1,web-2"})
      assert %{queues: ~w(alpha gamma)} = decode_params(%{"queues" => "alpha,gamma"})
      assert %{workers: ~w(A B)} = decode_params(%{"workers" => "A,B"})
    end

    test "decoding params with path qualifiers" do
      assert %{args: [~w(a), "x"]} = decode_params(%{"args" => "a++x"})
      assert %{args: [~w(a b), "x"]} = decode_params(%{"args" => "a,b++x"})
      assert %{meta: [~w(a), "x"]} = decode_params(%{"meta" => "a++x"})
    end
  end

  describe "suggest/2" do
    def suggest(terms), do: Query.suggest(terms, @conf)

    def sorted_suggest(terms) do
      terms
      |> Query.suggest(@conf)
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

      assert [_, _] = Query.suggest("workers:", @conf, resolver: HintResolver)
      assert [_, _, _] = Query.suggest("queues:", @conf, resolver: HintResolver)
    end
  end

  describe "complete/2" do
    def complete(terms) do
      Query.complete(terms, @conf)
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
  end

  describe "append/2" do
    import Query, only: [append: 2]

    test "appending new qualifiers" do
      assert "queues:" == append("qu", "queues:")
      assert "queues:" == append("queue", "queues:")
      assert "queues:" == append("queue:", "queues:")
      assert "args." == append("arg", "args.")
    end

    test "preventing duplicate qualifier values" do
      assert "queues:" == append("queues:", "queues:")
    end

    test "quoting terms with whitespace" do
      assert ~s(args.account:"A B C") == append("args.account:A", "A B C")
      assert ~s(args.account:"A,B,C") == append("args.account:A", "A,B,C")
    end
  end

  describe "all_jobs/2" do
    test "filtering by id" do
      job_1 = insert_job!(%{ref: 1})
      job_2 = insert_job!(%{ref: 2})
      job_3 = insert_job!(%{ref: 3})

      assert [1] = filter_refs(ids: ~w(#{job_1.id}))
      assert [1, 2] = filter_refs(ids: ~w(#{job_1.id} #{job_2.id}))
      assert [1, 3] = filter_refs(ids: ~w(#{job_1.id} #{job_3.id}))
      assert [] = filter_refs(ids: ~w(12345))
    end

    test "filtering by node" do
      insert_job!(%{ref: 1}, attempted_by: ["worker.1", "abc-123"])
      insert_job!(%{ref: 2}, attempted_by: ["worker.2", "abc-123"])

      assert [1] = filter_refs(nodes: ~w(worker.1))
      assert [2] = filter_refs(nodes: ~w(worker.2))
      assert [1, 2] = filter_refs(nodes: ~w(worker.1 worker.2))
      assert [] = filter_refs(nodes: ~w(web.1))
    end

    test "filtering by priority" do
      insert_job!(%{ref: 0}, priority: 0)
      insert_job!(%{ref: 1}, priority: 1)
      insert_job!(%{ref: 2}, priority: 2)

      assert [0] = filter_refs(priorities: ~w(0))
      assert [0, 1] = filter_refs(priorities: ~w(0 1))
      assert [0, 1, 2] = filter_refs(priorities: ~w(0 1 2 3))
      assert [] = filter_refs(priorities: ~w(3))
    end

    test "filtering by queue" do
      insert_job!(%{ref: 1}, queue: "alpha")
      insert_job!(%{ref: 2}, queue: "gamma")

      assert [1] = filter_refs(queues: ~w(alpha))
      assert [2] = filter_refs(queues: ~w(gamma))
      assert [1, 2] = filter_refs(queues: ~w(alpha gamma))
      assert [] = filter_refs(queues: ~w(delta))
    end

    test "filtering by state" do
      insert_job!(%{ref: 0}, state: "available")
      insert_job!(%{ref: 1}, state: "available")
      insert_job!(%{ref: 2}, state: "scheduled")
      insert_job!(%{ref: 3}, state: "completed")

      assert [0, 1] = filter_refs(state: "available")
      assert [] = filter_refs(state: "executing")
    end

    test "filtering by tags" do
      insert_job!(%{ref: 0}, tags: ["audio"])
      insert_job!(%{ref: 1}, tags: ["audio", "video"])
      insert_job!(%{ref: 2}, tags: ["video"])

      assert [0, 1] = filter_refs(tags: ~w(audio))
      assert [1, 2] = filter_refs(tags: ~w(video))
      assert [0, 1, 2] = filter_refs(tags: ~w(audio video))
      assert [0, 1] = filter_refs(tags: ~w(audio nada))
      assert [] = filter_refs(tags: ~w(nada))
    end

    test "filtering by worker" do
      insert_job!(%{ref: 1}, worker: MyApp.VideoA)
      insert_job!(%{ref: 2}, worker: MyApp.VideoB)

      assert [1] = filter_refs(workers: ~w(MyApp.VideoA))
      assert [2] = filter_refs(workers: ~w(MyApp.VideoB))
      assert [1, 2] = filter_refs(workers: ~w(MyApp.VideoA MyApp.VideoB))
      assert [] = filter_refs(workers: ~w(MyApp.Video))
    end

    test "searching within args sub-fields" do
      insert_job!(%{ref: 0, mode: "audio", bar: %{baz: 1}})
      insert_job!(%{ref: 1, mode: "video", bar: %{baz: 2}})
      insert_job!(%{ref: 2, mode: "media", bar: %{bat: 3}})

      assert [0] = filter_refs(args: [~w(mode), "audio"])
      assert [1] = filter_refs(args: [~w(mode), "video"])

      assert [0] = filter_refs(args: [~w(bar baz), "1"])
      assert [2] = filter_refs(args: [~w(bar bat), "3"])
      assert [] = filter_refs(args: [~w(bar bat), "4"])
    end

    test "searching within meta sub-fields" do
      insert_job!(%{ref: 0}, meta: %{mode: "audio", bar: %{baz: "21f8"}})
      insert_job!(%{ref: 1}, meta: %{mode: "video", bar: %{baz: 7050}})
      insert_job!(%{ref: 2}, meta: %{mode: "media", bar: %{bat: "4b0e"}})

      assert [0] = filter_refs(meta: [~w(mode), "audio"])
      assert [0] = filter_refs(meta: [~w(bar baz), "21f8"])
      assert [1] = filter_refs(meta: [~w(bar baz), "7050"])
      assert [2] = filter_refs(meta: [~w(bar bat), "4b0e"])
    end

    test "filtering by multiple terms" do
      insert_job!(%{ref: 0, mode: "video"}, worker: Media, meta: %{batch_id: 1})
      insert_job!(%{ref: 1, mode: "audio"}, worker: Media, meta: %{batch_id: 1})
      insert_job!(%{ref: 2, mode: "multi"}, worker: Media, meta: %{batch_id: 2})

      assert [0, 1] = filter_refs(workers: ~w(Media), meta: [~w(batch_id), "1"])
      assert [2] = filter_refs(args: [~w(mode), "multi"], meta: [~w(batch_id), "2"])
    end

    test "ordering fields by state" do
      ago = fn sec -> DateTime.add(DateTime.utc_now(), -sec) end

      job_a = insert_job!(%{}, state: "cancelled", cancelled_at: ago.(4))
      job_b = insert_job!(%{}, state: "cancelled", cancelled_at: ago.(6))
      job_c = insert_job!(%{}, state: "cancelled", cancelled_at: ago.(1))

      assert [job_c.id, job_a.id, job_b.id] ==
               %{state: "cancelled"}
               |> Query.all_jobs(@conf)
               |> Enum.map(& &1.id)

      assert [job_b.id, job_a.id, job_c.id] ==
               %{state: "cancelled", sort_dir: "desc"}
               |> Query.all_jobs(@conf)
               |> Enum.map(& &1.id)
    end

    test "restrict the query with a resolver that implements jobs_query_limit/1" do
      defmodule JobResolver do
        def jobs_query_limit(:completed), do: 1
        def jobs_query_limit(:executing), do: 10
      end

      insert_job!(%{ref: 0}, state: "executing")
      insert_job!(%{ref: 1}, state: "executing")
      insert_job!(%{ref: 2}, state: "executing")
      insert_job!(%{ref: 3}, state: "completed")
      insert_job!(%{ref: 4}, state: "completed")
      insert_job!(%{ref: 5}, state: "completed")

      assert [0, 1, 2] = filter_refs(%{state: "executing"}, resolver: JobResolver)
      assert [4, 5] = filter_refs(%{state: "completed"}, resolver: JobResolver)
    end
  end

  defp filter_refs(params, opts \\ []) do
    params =
      params
      |> Map.new()
      |> Map.put_new(:state, "available")

    params
    |> Query.all_jobs(@conf, opts)
    |> Enum.map(& &1.args["ref"])
    |> Enum.sort()
  end
end
