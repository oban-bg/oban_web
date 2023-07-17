defmodule Oban.Web.QueryTest do
  use Oban.Web.Case, async: true

  alias Oban.Config
  alias Oban.Web.{Query, Repo}

  @conf Config.new(repo: Repo)

  describe "all_jobs/2" do
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

    test "constraining by state" do
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

    test "searching within args" do
      insert_job!(%{ref: 0, mode: "video", domain: "myapp"})
      insert_job!(%{ref: 1, mode: "audio", domain: "myapp"})
      insert_job!(%{ref: 2, mode: "multi", domain: "myapp"})

      assert [0] = filter_refs(args: "video")
      assert [1] = filter_refs(args: "audio")
      assert [0, 1, 2] = filter_refs(args: "myapp")
      assert [0, 1] = filter_refs(args: "video or audio")
      assert [] = filter_refs(args: "nada")
    end

    test "searching within args sub-fields" do
      insert_job!(%{ref: 0, mode: "audio", bar: %{baz: 1}})
      insert_job!(%{ref: 1, mode: "video", bar: %{baz: 2}})
      insert_job!(%{ref: 2, mode: "media", bar: %{bat: 3}})

      assert [0] = filter_refs(args: {~w(mode), "audio"})
      assert [1] = filter_refs(args: {~w(mode), "video"})
      assert [0, 1] = filter_refs(args: {~w(mode), "audio or video"})

      assert [0] = filter_refs(args: {~w(bar baz), "1"})
      assert [0, 1] = filter_refs(args: {~w(bar), "baz"})
      assert [2] = filter_refs(args: {~w(bar bat), "3"})
      assert [] = filter_refs(args: {~w(bar bat), "4"})
    end

    test "searching within meta" do
      insert_job!(%{ref: 0}, meta: %{mode: "video", domain: "myapp"})
      insert_job!(%{ref: 1}, meta: %{mode: "audio", domain: "myapp"})
      insert_job!(%{ref: 2}, meta: %{mode: "multi", domain: "myapp"})

      assert [0] = filter_refs(meta: "video")
      assert [1] = filter_refs(meta: "audio")
      assert [0, 1, 2] = filter_refs(meta: "myapp")
      assert [0, 1] = filter_refs(meta: "video or audio")
      assert [] = filter_refs(meta: "nada")
    end

    test "searching within meta sub-fields" do
      insert_job!(%{ref: 0}, meta: %{mode: "audio", bar: %{baz: 1}})
      insert_job!(%{ref: 1}, meta: %{mode: "video", bar: %{baz: 2}})
      insert_job!(%{ref: 2}, meta: %{mode: "media", bar: %{bat: 3}})

      assert [0] = filter_refs(meta: {~w(mode), "audio"})
      assert [1] = filter_refs(meta: {~w(mode), "video"})
      assert [0, 1] = filter_refs(meta: {~w(mode), "audio or video"})

      assert [0] = filter_refs(meta: {~w(bar baz), "1"})
      assert [0, 1] = filter_refs(meta: {~w(bar), "baz"})
      assert [2] = filter_refs(meta: {~w(bar bat), "3"})
      assert [] = filter_refs(meta: {~w(bar bat), "4"})
    end

    test "ignoring the meta recorded column" do
      insert_job!(%{ref: 1}, meta: %{recorded: "video"})
      insert_job!(%{ref: 2}, meta: %{searched: "video"})

      assert [2] = filter_refs(meta: "video")
    end

    test "negating search terms" do
      insert_job!(%{ref: 0, mode: "video"})
      insert_job!(%{ref: 1, mode: "audio"})
      insert_job!(%{ref: 2}, meta: %{mode: "video"})
      insert_job!(%{ref: 3}, meta: %{mode: "audio"})

      assert [1, 2, 3] = filter_refs(args: "-video")
      assert [0, 1, 3] = filter_refs(meta: "-video")
    end

    test "filtering by multiple terms" do
      insert_job!(%{ref: 0, mode: "video"}, worker: Media, meta: %{batch_id: 1})
      insert_job!(%{ref: 1, mode: "audio"}, worker: Media, meta: %{batch_id: 1})
      insert_job!(%{ref: 2, mode: "multi"}, worker: Media, meta: %{batch_id: 2})

      assert [0] = filter_refs(workers: ~w(Media), args: "video", meta: {~w(batch_id), "1"})
      assert [1] = filter_refs(workers: ~w(Media), args: "audio", meta: {~w(batch_id), "1"})
      assert [2] = filter_refs(args: "multi", meta: {~w(batch_id), "2"})
      assert [] = filter_refs(args: "audio", meta: {~w(batch_id), "2"})
    end

    test "ordering fields by state" do
      ago = fn sec -> DateTime.add(DateTime.utc_now(), -sec) end

      job_a = insert_job!(%{}, state: "cancelled", cancelled_at: ago.(4))
      job_b = insert_job!(%{}, state: "cancelled", cancelled_at: ago.(6))
      job_c = insert_job!(%{}, state: "cancelled", cancelled_at: ago.(1))

      assert [job_b.id, job_a.id, job_c.id] ==
               @conf
               |> Query.all_jobs(%{state: "cancelled"})
               |> Enum.map(& &1.id)

      assert [job_c.id, job_a.id, job_b.id] ==
               @conf
               |> Query.all_jobs(%{state: "cancelled", sort_dir: "desc"})
               |> Enum.map(& &1.id)
    end
  end

  defp filter_refs(terms) do
    terms =
      terms
      |> Map.new()
      |> Map.put_new(:state, "available")

    @conf
    |> Query.all_jobs(terms)
    |> Enum.map(& &1.args["ref"])
    |> Enum.sort()
  end
end
