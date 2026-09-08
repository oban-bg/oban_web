if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.ProFixtures do
    @moduledoc false

    import Ecto.Query, only: [order_by: 2, where: 3]
    import ExUnit.Assertions, only: [assert_receive: 2]

    alias Oban.Job
    alias Oban.Pro.{Testing, Workflow}
    alias Oban.Web.Repo

    # Workers

    defmodule StepWorker do
      @moduledoc false

      use Oban.Pro.Worker, max_attempts: 1

      @impl Oban.Pro.Worker
      def process(%Job{args: %{"result" => "error"}}), do: {:error, "step failed"}
      def process(%Job{args: %{"result" => "cancel"}}), do: {:cancel, "step cancelled"}
      def process(%Job{args: %{"result" => "snooze"}}), do: {:snooze, 60}
      def process(_job), do: :ok
    end

    defmodule ChargeCard do
      @moduledoc false

      @behaviour Oban.Pro.Workflow

      use Oban.Pro.Worker, max_attempts: 1

      @impl Oban.Pro.Worker
      def process(_job), do: :ok

      @impl Oban.Pro.Workflow
      def compensate(%Job{args: %{"refund" => "error"}}), do: {:error, "refund failed"}
      def compensate(_job), do: :ok
    end

    defmodule ShipOrder do
      @moduledoc false

      use Oban.Pro.Worker, max_attempts: 1

      @impl Oban.Pro.Worker
      def process(%Job{args: %{"result" => "error"}}), do: {:error, "carrier unavailable"}
      def process(_job), do: :ok
    end

    defmodule RecordedWorker do
      @moduledoc false

      # The recorded stage checks that the storage module is loaded while this worker compiles.
      Code.ensure_compiled!(Oban.Web.StorageMock)

      use Oban.Pro.Worker, recorded: [storage: Oban.Web.StorageMock]

      @impl Oban.Pro.Worker
      def process(%Job{args: %{"total" => total}}), do: {:ok, %{total: total}}
    end

    defmodule ChunkWorker do
      @moduledoc false

      use Oban.Pro.Chunk, queue: :chunks, size: 3, sleep: 10, timeout: 100

      @impl Oban.Pro.Worker
      def process(jobs) do
        case Enum.find_value(jobs, & &1.args["block"]) do
          nil -> :ok
          listener -> Oban.Web.ProFixtures.block_chunk(listener)
        end

        case Enum.filter(jobs, &(&1.args["result"] == "error")) do
          [] -> :ok
          failed -> {:error, "chunk failed", failed}
        end
      end
    end

    defmodule ChainWorker do
      @moduledoc false

      use Oban.Pro.Worker, queue: :default, max_attempts: 1, chain: [by: :worker]

      @impl Oban.Pro.Worker
      def process(%Job{args: %{"result" => "error"}}), do: {:error, "link failed"}
      def process(_job), do: :ok
    end

    defmodule BackfillWorker do
      @moduledoc false

      use Oban.Pro.Backfill, queue: :default, limit: 10

      # Windows advance a counter rather than a table, so no schema is needed to run a backfill.
      @impl Oban.Pro.Backfill
      def backfill(%{value: value, limit: limit} = cursor, %{total: total}) do
        start = value || 0

        if start >= total do
          :halt
        else
          count = min(limit, total - start)

          {:cont, %{cursor | value: start + count}, count}
        end
      end
    end

    defmodule WaitingChunkWorker do
      @moduledoc false

      use Oban.Pro.Chunk, queue: :chunks, size: 3, sleep: 10, timeout: 2_000

      @impl Oban.Pro.Worker
      def process(_jobs), do: :ok
    end

    defmodule Reports do
      @moduledoc false

      use Oban.Pro.Decorator

      @job true
      def digest, do: :ok

      @job true
      def cleanup, do: :ok

      @job true
      def weekly(account_id), do: {:ok, account_id}
    end

    # Recorded

    def run_recorded!(oban, total) do
      [job] =
        Testing.run_jobs([RecordedWorker.new(%{total: total})], oban: oban, with_summary: false)

      Repo.reload!(job)
    end

    # Chains

    def run_chain!(oban, args_list) do
      changesets = Enum.map(args_list, &ChainWorker.new/1)
      last_id = last_job_id()

      Testing.run_jobs(changesets, oban: oban, with_summary: false)

      jobs_since(last_id)
    end

    # Backfills

    # Draining recursively runs each window's successor as it is inserted, so the backfill runs
    # to completion and the final job is the one that halted.
    def run_backfill!(oban, total) do
      last_id = last_job_id()

      Testing.run_jobs([BackfillWorker.new(%{total: total})], oban: oban, with_summary: false)

      jobs_since(last_id)
    end

    # Chunks

    def run_chunk!(oban, args_list) do
      changesets = Enum.map(args_list, &ChunkWorker.new/1)
      last_id = last_job_id()

      # Without staging, jobs the chunk marks retryable stay that way instead of running again.
      Testing.run_chunk(changesets, oban: oban, size: length(changesets), with_scheduled: false)

      jobs_since(last_id)
    end

    # The test pid rides along in the args so the executing chunk can report back without a
    # registered name, which would collide between concurrent tests.
    def start_blocked_chunk!(oban, args_list) do
      listener = self() |> :erlang.pid_to_list() |> List.to_string()
      changesets = Enum.map(args_list, &ChunkWorker.new(Map.put(&1, :block, listener)))
      last_id = last_job_id()

      Oban.insert_all(oban, changesets)

      assert_receive {:chunk_running, worker_pid}, 5_000

      {worker_pid, jobs_since(last_id)}
    end

    def start_waiting_chunk!(oban, args) do
      [job] = Oban.insert_all(oban, [WaitingChunkWorker.new(args)])

      wait_until(fn -> Repo.reload!(job).state == "executing" end)

      Repo.reload!(job)
    end

    def block_chunk(listener) do
      listener
      |> String.to_charlist()
      |> :erlang.list_to_pid()
      |> send({:chunk_running, self()})

      receive do
        :chunk_finish -> :ok
      after
        5_000 -> :ok
      end
    end

    def finish_chunk(worker_pid), do: send(worker_pid, :chunk_finish)

    defp last_job_id, do: Repo.aggregate(Job, :max, :id) || 0

    defp jobs_since(last_id) do
      Job
      |> where([j], j.id > ^last_id)
      |> order_by(asc: :id)
      |> Repo.all()
    end

    # Workflows

    def build_workflow(opts \\ []) do
      {steps, opts} = Keyword.pop(opts, :steps, [[]])
      {subs, opts} = Keyword.pop(opts, :subs, [])

      workflow =
        steps
        |> Enum.with_index(1)
        |> Enum.reduce(Workflow.new(opts), fn {step, index}, acc ->
          {name, step} = Keyword.pop(step, :name, :"step_#{index}")
          {deps, step} = Keyword.pop(step, :deps, [])

          Workflow.add(acc, name, step_changeset(step), deps: deps)
        end)

      subs
      |> Enum.with_index(1)
      |> Enum.reduce(workflow, fn {sub, index}, acc ->
        {name, sub} = Keyword.pop(sub, :name, :"sub_#{index}")
        {deps, sub} = Keyword.pop(sub, :deps, [])

        Workflow.add_workflow(acc, name, build_workflow(sub), deps: deps)
      end)
    end

    def insert_workflow!(oban, opts \\ []) do
      Oban.insert_all(oban, build_workflow(opts))
    end

    def run_workflow!(oban, opts \\ [], drain_opts \\ []) do
      drain_opts = Keyword.merge([oban: oban, with_summary: false], drain_opts)

      Testing.run_workflow(build_workflow(opts), drain_opts)
    end

    defp step_changeset(step) do
      {worker, step} = Keyword.pop(step, :worker, StepWorker)
      {args, step} = Keyword.pop(step, :args, %{})

      if is_atom(worker) do
        worker.new(args, step)
      else
        Job.new(args, Keyword.put(step, :worker, worker))
      end
    end

    # Sagas

    def build_saga(opts \\ []) do
      {charge_args, opts} = Keyword.pop(opts, :charge_args, %{})
      {ship_args, opts} = Keyword.pop(opts, :ship_args, %{})

      opts
      |> Keyword.put_new(:workflow_name, "payment-saga")
      |> Keyword.put_new(:compensate_on, [:discarded])
      |> Workflow.new()
      |> Workflow.add(:charge, ChargeCard.new(charge_args))
      |> Workflow.add(:ship, ShipOrder.new(ship_args), deps: [:charge])
    end

    def insert_saga!(oban, opts \\ []) do
      workflow = build_saga(opts)

      Oban.insert_all(oban, workflow)

      saga(oban, workflow.id)
    end

    def run_failed_saga!(oban, opts \\ []) do
      workflow =
        opts
        |> Keyword.put(:ship_args, %{result: "error"})
        |> build_saga()

      Oban.insert_all(oban, workflow)

      # Draining recursively would follow the compensation Pro materializes and run it too, so
      # drain one pass per step instead.
      drain_opts = [oban: oban, queue: :all, with_recursion: false, workflow_ids: [workflow.id]]

      Testing.drain_jobs(drain_opts)
      Testing.drain_jobs(drain_opts)

      saga(oban, workflow.id)
    end

    def compensate_saga!(%{oban: oban, compensation_id: compensation_id} = saga) do
      Testing.drain_jobs(oban: oban, queue: :all, workflow_ids: [compensation_id])

      saga(oban, saga.id)
    end

    def compensation_steps(%{oban: oban, compensation_id: compensation_id}) do
      oban
      |> Workflow.all_jobs(compensation_id)
      |> Enum.sort_by(& &1.id)
    end

    defp saga(oban, workflow_id) do
      %{compensation: compensation} = Workflow.status(oban, workflow_id)

      jobs =
        oban
        |> Workflow.all_jobs(workflow_id)
        |> Map.new(&{&1.meta["name"], &1})

      %{
        id: workflow_id,
        oban: oban,
        compensation_id: compensation && compensation.id,
        jobs: jobs
      }
    end

    # Crons

    # This is the entry Oban.Pro.Cron builds when it discovers an `@job cron:` annotation. Real
    # discovery needs the :oban_pro compiler and would register the entry with every Cron plugin
    # in the suite, so it's built by hand instead. Oban.Cron entries can't take a `name` option.
    def decorated_cron_entry(expression, opts \\ []) do
      {fun, opts} = Keyword.pop(opts, :fun, "digest")

      entry_opts =
        [
          args: %{mod: inspect(Reports), fun: fun, arg: []},
          meta: %{decorated: true, decorated_name: decorated_cron_name(fun)}
        ]
        |> Keyword.merge(opts)

      {expression, Oban.Pro.Decorator, entry_opts}
    end

    def decorated_cron_name(fun \\ "digest"), do: "#{inspect(Reports)}.#{fun}/0"

    # Helpers

    defp wait_until(fun, attempts \\ 200) do
      cond do
        fun.() ->
          :ok

        attempts == 0 ->
          raise "condition never met"

        true ->
          Process.sleep(5)
          wait_until(fun, attempts - 1)
      end
    end
  end
end
