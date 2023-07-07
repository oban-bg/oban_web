defmodule Oban.Web.SearchTest do
  use Oban.Web.Case, async: true

  alias Oban.Web.Search

  @moduletag :search

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

  defp assert_matches(expected_refs, query) do
    actual_refs =
      query
      |> Search.build()
      |> select([j], j.args["ref"])
      |> Repo.all()

    assert Enum.sort(actual_refs) == Enum.sort(expected_refs)
  end
end
