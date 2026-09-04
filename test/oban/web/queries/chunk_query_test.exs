if Code.ensure_loaded?(Oban.Pro.Chunk) do
  defmodule Oban.Web.Repo.ChunkQueryTest.ChunkWorker do
    use Oban.Pro.Chunk, queue: :chunks, size: 3, timeout: 100

    @impl Oban.Pro.Chunk
    def process_chunk([_ | _]) do
      send(:chunk_test, {:chunk_running, self()})

      receive do
        :chunk_finish -> :ok
      after
        5_000 -> :ok
      end
    end
  end
end

defmodule Oban.Web.Repo.ChunkQueryTest do
  use Oban.Web.Case, async: false

  import Oban.Web.Helpers, only: [chunk_count: 1, chunk_leader?: 1, chunk_leader_id: 1]

  alias Oban.Web.JobQuery
  alias Oban.Web.Repo.ChunkQueryTest.ChunkWorker

  @moduletag :pro

  @compile {:no_warn_undefined, ChunkWorker}

  setup do
    name =
      start_supervised_oban!(engine: Oban.Pro.Engine, queues: [chunks: 1], stage_interval: 10)

    Process.register(self(), :chunk_test)

    {:ok, conf: Oban.config(name)}
  end

  test "recognizing the leader and siblings of a running chunk", %{conf: conf} do
    Oban.insert_all(for ref <- 1..3, do: ChunkWorker.new(%{ref: ref}))

    assert_receive {:chunk_running, worker_pid}, 5_000

    {[leader], siblings} =
      Job
      |> Repo.all()
      |> Enum.split_with(&chunk_leader?/1)

    assert 3 == chunk_count(leader)
    assert 2 == length(siblings)
    assert Enum.all?(siblings, &(chunk_leader_id(&1) == leader.id))
    assert Enum.all?(siblings, &is_nil(chunk_count(&1)))

    assert [leader.id] == job_ids(conf, %{state: "executing"})

    assert Enum.sort([leader.id | Enum.map(siblings, & &1.id)]) ==
             job_ids(conf, %{state: "executing", chunks: [leader.id]})

    send(worker_pid, :chunk_finish)

    with_backoff(fn ->
      assert %{"completed" => 3} == JobQuery.chunk_counts(conf, Repo.reload!(leader))
    end)

    assert 3 == length(job_ids(conf, %{state: "completed"}))
  end

  defp job_ids(conf, params) do
    params
    |> JobQuery.all_jobs(conf)
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end
end
