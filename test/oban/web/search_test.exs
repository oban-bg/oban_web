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
    assert_matches([], "id:")
  end

  test "searching in worker, tags, args and meta by default" do
    insert_job!(%{ref: 1}, worker: MyApp.Video)
    insert_job!(%{ref: 2, mode: "video"})
    insert_job!(%{ref: 3}, tags: ["audio", "video"])
    insert_job!(%{ref: 4}, meta: %{mode: "video"})

    assert_matches([1, 2, 3, 4], "video")
  end

  test "constraining search using the in:field qualifier" do
    insert_job!(%{ref: 1}, worker: MyApp.Video)
    insert_job!(%{ref: 2, mode: "video", domain: "myapp"})
    insert_job!(%{ref: 3}, meta: %{mode: "audio"})
    insert_job!(%{ref: 4}, tags: ["audio", "video"])

    assert_matches([1], "myapp in:worker")
    assert_matches([2], "video in:args")
    assert_matches([3], "audio in:meta")
    assert_matches([4], "audio in:tags")
    assert_matches([], "audio in:")

    assert_matches([1, 2], "myapp in:args,worker")
    assert_matches([2, 4], "video in:args,tags")
    assert_matches([3, 4], "audio in:meta,tags")

    assert_matches([1, 2, 4], "video in:args,meta,tags,worker")
  end

  test "negating terms" do
    insert_job!(%{ref: 1}, worker: Video)
    insert_job!(%{ref: 2, mode: "video"})
    insert_job!(%{ref: 3}, tags: ["video"])
    insert_job!(%{ref: 4}, meta: %{mode: "video"})

    assert_matches([1, 3, 4], "-video in:args")
    assert_matches([1, 2, 3], "-video in:meta")
    assert_matches([1, 2, 4], "-video in:tags")

    assert_matches([1, 2, 4], "not video in:tags")
    assert_matches([1, 2, 4], "video not in:tags")
  end

  test "searching by priority" do
    insert_job!(%{ref: 0}, worker: MyApp.Video, priority: 0)
    insert_job!(%{ref: 1}, worker: MyApp.Video, priority: 1)
    insert_job!(%{ref: 2}, worker: MyApp.Video, priority: 2)

    assert_matches([0], "priority:0")
    assert_matches([0, 1], "priority:0,1")
    assert_matches([0, 1, 2], "priority:0,1,2,3")
    assert_matches([], "priority:3")
    assert_matches([], "priority:")

    assert_matches([2], "video priority:2")
  end

  test "searching within args sub-fields" do
    insert_job!(%{ref: 0, foo: 1, bar: %{baz: 1}})
    insert_job!(%{ref: 1, foo: 2, bar: %{baz: 2}})
    insert_job!(%{ref: 2, foo: 3, bar: %{bat: 3}})

    assert_matches([0], "1 in:args.foo")
    assert_matches([0], "1 in:args.bar.baz")
    assert_matches([0, 1], "baz in:args.bar")
    assert_matches([2], "3 in:args.bar.bat")
    assert_matches([2], "3 in:args.bar.bat,meta.bar")
  end

  test "searching within meta sub-fields" do
    insert_job!(%{ref: 0}, meta: %{foo: 1, bar: %{baz: 1}})
    insert_job!(%{ref: 1}, meta: %{foo: 2, bar: %{baz: 2}})
    insert_job!(%{ref: 2}, meta: %{foo: 3, bar: %{bat: 3}})

    assert_matches([0], "1 in:meta.foo")
    assert_matches([0], "1 in:meta.bar.baz")
    assert_matches([0, 1], "baz in:meta.bar")
    assert_matches([2], "3 in:meta.bar.bat")
    assert_matches([2], "3 in:args,meta.bar.bat,worker")
  end

  test "ignoring invalid fields or syntax" do
    assert_matches([], "what in:")
    assert_matches([], "what in:thing")
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
