defmodule Oban.Web.SearchTest do
  use Oban.Web.DataCase, async: true

  alias Oban.Web.Search

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

    assert_matches([2], "video priority:2")
  end

  # dates
  # field sub-access

  defp assert_matches(expected_refs, query) do
    actual_refs =
      query
      |> Search.build()
      |> select([j], j.args["ref"])
      |> Repo.all()

    assert Enum.sort(actual_refs) == Enum.sort(expected_refs)
  end
end
