defmodule Oban.Web.SearchTest do
  use Oban.Web.Case, async: true

  alias Oban.Web.Search

  @moduletag :search

  describe "build/2" do
    test "constraining by id" do
      job_1 = insert_job!(%{ref: 1})
      job_2 = insert_job!(%{ref: 2})

      assert_matches([1], "id:#{job_1.id}")
      assert_matches([2], "id:#{job_2.id}")
      assert_matches([1, 2], "id:#{job_1.id},#{job_2.id}")
    end

    test "constraining by node" do
      insert_job!(%{ref: 1}, attempted_by: ["worker.1", "abc-123"])
      insert_job!(%{ref: 2}, attempted_by: ["worker.2", "abc-123"])

      assert_matches([1], "node:worker.1")
      assert_matches([2], "node:worker.2")
      assert_matches([1, 2], "node:worker.1,worker.2")
      assert_matches([], "node:web.1")
    end

    test "constraining by priority" do
      insert_job!(%{ref: 0}, priority: 0)
      insert_job!(%{ref: 1}, priority: 1)
      insert_job!(%{ref: 2}, priority: 2)

      assert_matches([0], "priority:0")
      assert_matches([0, 1], "priority:0,1")
      assert_matches([0, 1, 2], "priority:0,1,2,3")
      assert_matches([], "priority:3")
    end

    test "constraining by queue" do
      insert_job!(%{ref: 1}, queue: "alpha")
      insert_job!(%{ref: 2}, queue: "gamma")

      assert_matches([1], "queue:alpha")
      assert_matches([2], "queue:gamma")
      assert_matches([1, 2], "queue:alpha,gamma")
      assert_matches([], "queue:delta")
    end

    test "constraining by state" do
      insert_job!(%{ref: 0}, state: "available")
      insert_job!(%{ref: 1}, state: "available")
      insert_job!(%{ref: 2}, state: "scheduled")
      insert_job!(%{ref: 3}, state: "completed")

      assert_matches([0, 1], "state:available")
      assert_matches([2, 3], "state:scheduled,completed")
      assert_matches([], "state:executing")
    end

    test "constraining by tags" do
      insert_job!(%{ref: 0}, tags: ["audio"])
      insert_job!(%{ref: 1}, tags: ["audio", "video"])
      insert_job!(%{ref: 2}, tags: ["video"])

      assert_matches([0, 1], "tags:audio")
      assert_matches([1, 2], "tags:video")
      assert_matches([0, 1, 2], "tags:audio,video")
      assert_matches([0, 1], "tags:audio,nada")
      assert_matches([], "tags:nada")
    end

    test "constraining by worker" do
      insert_job!(%{ref: 1}, worker: MyApp.VideoA)
      insert_job!(%{ref: 2}, worker: MyApp.VideoB)

      assert_matches([1], "worker:MyApp.VideoA")
      assert_matches([2], "worker:MyApp.VideoB")
      assert_matches([1, 2], "worker:MyApp.VideoA,MyApp.VideoB")
      assert_matches([], "worker:MyApp.Video")
    end

    test "searching within args" do
      insert_job!(%{ref: 0, mode: "video", domain: "myapp"})
      insert_job!(%{ref: 1, mode: "audio", domain: "myapp"})
      insert_job!(%{ref: 2, mode: "multi", domain: "myapp"})

      assert_matches([0], "args:video")
      assert_matches([1], "args:audio")
      assert_matches([0, 1, 2], "args:myapp")
      assert_matches([0, 1], ~s(args:"video or audio"))
    end

    test "searching within args sub-fields" do
      insert_job!(%{ref: 0, mode: "audio", bar: %{baz: 1}})
      insert_job!(%{ref: 1, mode: "video", bar: %{baz: 2}})
      insert_job!(%{ref: 2, mode: "media", bar: %{bat: 3}})

      assert_matches([0], "args.mode:audio")
      assert_matches([1], "args.mode:video")
      assert_matches([0, 1], ~s(args.mode:"audio or video"))

      assert_matches([0], "args.bar.baz:1")
      assert_matches([0, 1], "args.bar:baz")
      assert_matches([2], "args.bar.bat:3")
      assert_matches([], "args.bar.bat:4")
    end

    test "searching within meta" do
      insert_job!(%{ref: 0}, meta: %{mode: "video", domain: "myapp"})
      insert_job!(%{ref: 1}, meta: %{mode: "audio", domain: "myapp"})
      insert_job!(%{ref: 2}, meta: %{mode: "multi", domain: "myapp"})

      assert_matches([0], "meta:video")
      assert_matches([1], "meta:audio")
      assert_matches([0, 1, 2], "meta:myapp")
      assert_matches([0, 1], ~s(meta:"video or audio"))
    end

    test "searching within meta sub-fields" do
      insert_job!(%{ref: 0}, meta: %{mode: "audio"})
      insert_job!(%{ref: 1}, meta: %{mode: "video"})
      insert_job!(%{ref: 2}, meta: %{mode: "media"})

      assert_matches([0], "meta.mode:audio")
      assert_matches([1], "meta.mode:video")
      assert_matches([0, 1], ~s(meta.mode:"audio or video"))
    end

    test "negating terms" do
      insert_job!(%{ref: 0, mode: "video"})
      insert_job!(%{ref: 1, mode: "audio"})
      insert_job!(%{ref: 2}, meta: %{mode: "video"})
      insert_job!(%{ref: 3}, meta: %{mode: "audio"})

      assert_matches([1, 2, 3], "args:-video")
      assert_matches([0, 1, 3], "meta:-video")
    end

    test "ignoring the meta recorded column" do
      insert_job!(%{ref: 1}, meta: %{recorded: "video"})
      insert_job!(%{ref: 2}, meta: %{searched: "video"})

      assert_matches([2], "meta:video")
    end

    test "ignoring invalid fields or syntax" do
      assert_matches([], "in:   ")
      assert_matches([], "thing:")
    end

    test "composing multiple terms" do
      insert_job!(%{ref: 0, mode: "video"}, worker: Media, meta: %{batch_id: 1})
      insert_job!(%{ref: 1, mode: "audio"}, worker: Media, meta: %{batch_id: 1})
      insert_job!(%{ref: 2, mode: "multi"}, worker: Media, meta: %{batch_id: 2})

      assert_matches([0], "worker:Media args:video meta.batch_id:1")
      assert_matches([1], "worker:Media args:audio meta.batch_id:1")
      assert_matches([], "args:audio meta.batch_id:2")
    end
  end

  describe "suggest/2" do
    def suggest(terms, name \\ nil) do
      conf = if name, do: Oban.config(name), else: nil

      Search.suggest(terms, conf)
    end

    test "falling back to defaults without a query" do
      assert [{"args:", _, _} | _] = suggest("")
      assert [{"args:", _, _} | _] = suggest("  ")
    end

    test "falling back to defaults without any fragments" do
      assert [{"args:", _, _} | _] = suggest("priority:1 ")
      assert [{"args:", _, _} | _] = suggest("state:available priority:1 ")
    end

    test "suggesting qualifiers with fragments" do
      assert [{"priority:", _, _}] = suggest("prior")
      assert [{"priority:", _, _}] = suggest("priority")
    end

    test "ignoring unsuggestable qualifiers" do
      assert [] = suggest("args:")
      assert [] = suggest("args.id:")
      assert [] = suggest("id:")
      assert [] = suggest("meta:")
      assert [] = suggest("meta.batch_id:")
      assert [] = suggest("tags:")
    end

    test "suggesting fixed priorities" do
      assert [{"0", _, _} | _] = suggest("priority:")
      assert [{"0", _, _}] = suggest("priority:0")
      assert [{"1", _, _}] = suggest("priority:1")
    end

    test "suggesting fixed states" do
      assert [{"available", _, _} | _] = suggest("state:")
      assert [{"available", _, _}] = suggest("state:a")
      assert [{"available", _, _}] = suggest("state:available")

      assert [{"cancelled", _, _}] = suggest("state:can")
      assert [{"completed", _, _}] = suggest("state:com")
    end

    test "suggesting nodes" do
      name = start_supervised_oban!()

      store_labels(name, "node", "web.1@host")
      store_labels(name, "node", "web.2@host")
      store_labels(name, "node", "loc.8@host")

      assert [{"loc.8@host", _, _}, _, _] = suggest("node:", name)
      assert [{"web.1@host", _, _}, {"web.2@host", _, _}] = suggest("node:web", name)
      assert [{"web.1@host", _, _}, _] = suggest("node:web.1", name)

      stop_supervised!(name)
    end

    test "suggesting queues" do
      name = start_supervised_oban!()

      store_labels(name, "queue", "alpha")
      store_labels(name, "queue", "gamma")
      store_labels(name, "queue", "delta")

      assert [{"alpha", _, _}, _, _] = suggest("queue:", name)
      assert [{"alpha", _, _}, {"gamma", _, _}] = suggest("queue:a", name)
      assert [{"delta", _, _}] = suggest("queue:delta", name)

      stop_supervised!(name)
    end

    test "suggesting workers" do
      name = start_supervised_oban!()

      store_labels(name, "worker", "MyApp.Alpha")
      store_labels(name, "worker", "MyApp.Gamma")
      store_labels(name, "worker", "MyApp.Delta")

      assert [{"MyApp.Alpha", _, _}, _, _] = suggest("worker:", name)
      assert [{"MyApp.Alpha", _, _}, _, _] = suggest("worker:My", name)
      assert [{"MyApp.Delta", _, _}, _, _] = suggest("worker:MyApp.Delta", name)

      stop_supervised!(name)
    end

    test "suggesting with multiple terms" do
      assert [{"0", _, _} | _] = suggest("state:available priority:")
    end
  end

  describe "complete/2" do
    def complete(terms) do
      Search.complete(terms, nil)
    end

    test "completing with an unknown qualifier" do
      assert "stuff" == complete("stuff")
    end

    test "completing a qualifier" do
      assert "queue:" == complete("qu")
      assert "queue:" == complete("queue")
      assert "state:" == complete("st")
      assert "state:" == complete("state")

      assert "queue:alpha state:" == complete("queue:alpha st")
      assert "queue:alpha state:" == complete("queue:alpha state")
    end

    test "completing a value suggestion" do
      assert "state:available" == complete("state:ava")
      assert "priority:0 state:available" == complete("priority:0 state:ava")
    end
  end

  describe "append/2" do
    import Search, only: [append: 2]

    test "appending new qualifiers" do
      assert "queue:" == append("qu", "queue:")
      assert "queue:" == append("queue", "queue:")
      assert "queue:" == append("queue:", "queue:")
      assert "node:web queue:" == append("node:web que", "queue:")
    end

    test "preventing duplicate values" do
      assert "queue:" == append("queue:", "queue:")
    end
  end

  defp store_labels(name, label, value) do
    gauge = Oban.Met.Values.Gauge.new(1)

    name
    |> Oban.Registry.via(Oban.Met.Recorder)
    |> Oban.Met.Recorder.store(:exec_time, gauge, %{label => value})
  end

  defp assert_matches(expected_refs, query) do
    actual_refs =
      query
      |> Search.build()
      |> select([j], j.args["ref"])
      |> Repo.all()

    assert Enum.sort(actual_refs) == Enum.sort(expected_refs)
  end
end
