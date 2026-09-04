if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.ChunkQueryTest do
    use Oban.Web.ProCase

    import Oban.Web.Helpers, only: [chunk_count: 1, chunk_leader?: 1, chunk_leader_id: 1]

    alias Oban.Web.JobQuery

    describe "executing chunks" do
      setup do
        name = start_supervised_oban!(queues: [chunks: 1], stage_interval: 10)

        {:ok, conf: Oban.config(name)}
      end

      test "recognizing the leader and siblings of a running chunk", %{conf: conf} do
        {worker_pid, [leader | siblings]} =
          start_blocked_chunk!([%{ref: 1}, %{ref: 2}, %{ref: 3}])

        assert chunk_leader?(leader)
        assert 3 == chunk_count(leader)
        assert 2 == length(siblings)
        assert Enum.all?(siblings, &(chunk_leader_id(&1) == leader.id))
        assert Enum.all?(siblings, &is_nil(chunk_count(&1)))

        assert [leader.id] == job_ids(conf, %{state: "executing"})

        assert Enum.sort([leader.id | Enum.map(siblings, & &1.id)]) ==
                 job_ids(conf, %{state: "executing", chunks: [leader.id]})

        finish_chunk(worker_pid)

        with_backoff(fn ->
          assert %{"completed" => 3} == JobQuery.chunk_counts(conf, Repo.reload!(leader))
        end)

        assert 3 == length(job_ids(conf, %{state: "completed"}))
      end
    end

    describe "all_jobs/2 with a running queue" do
      setup do
        name = start_supervised_oban!(queues: [chunks: 1], stage_interval: 10)

        {:ok, conf: Oban.config(name)}
      end

      test "folding chunk siblings into their leader while executing", %{conf: conf} do
        {worker_pid, [leader, sibling]} = start_blocked_chunk!([%{ref: 1}, %{ref: 2}])

        # The blocked leader fills the queue, so this chunk is only picked up by the inline drain
        run_chunk!([%{ref: 4}, %{ref: 5}])

        insert_job!(%{ref: 3}, state: "executing", attempted_by: ["worker.2", "abc-123"])

        assert [1, 3] == filter_refs(conf, state: "executing")
        assert [1, 2] == filter_refs(conf, state: "executing", chunks: [leader.id])
        assert [2] == filter_refs(conf, state: "executing", ids: [sibling.id])
        assert [4, 5] == filter_refs(conf, state: "completed")

        finish_chunk(worker_pid)
      end
    end

    describe "all_jobs/2" do
      setup do
        {:ok, conf: Oban.config(start_supervised_oban!())}
      end

      test "filtering by chunk leader", %{conf: conf} do
        [leader | _siblings] = run_chunk!([%{ref: 1}, %{ref: 2}, %{ref: 3}])

        run_chunk!([%{ref: 4}])
        insert_job!(%{ref: 5}, state: "completed")

        assert [1, 2, 3] == filter_refs(conf, state: "completed", chunks: [leader.id])
        assert [] == filter_refs(conf, state: "completed", chunks: [999_999])
      end
    end

    describe "chunk_counts/2" do
      setup do
        {:ok, conf: Oban.config(start_supervised_oban!())}
      end

      test "counting a leader's chunk members by state, including the leader", %{conf: conf} do
        [leader | _siblings] =
          run_chunk!([%{ref: 1}, %{ref: 2}, %{ref: 3}, %{ref: 4, result: "error"}])

        # Another chunk's jobs aren't counted
        run_chunk!([%{ref: 5}])

        assert %{"completed" => 3, "retryable" => 1} == JobQuery.chunk_counts(conf, leader)
      end
    end

    defp filter_refs(conf, params) do
      params
      |> Map.new()
      |> JobQuery.all_jobs(conf)
      |> Enum.map(& &1.args["ref"])
      |> Enum.sort()
    end

    defp job_ids(conf, params) do
      params
      |> JobQuery.all_jobs(conf)
      |> Enum.map(& &1.id)
      |> Enum.sort()
    end
  end
end
