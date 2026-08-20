if Code.ensure_loaded?(Oban.Pro.Workflow.Compensation) do
  defmodule Oban.Web.CompensationFixture do
    @moduledoc false

    import Ecto.Query

    alias Oban.{Job, Repo}
    alias Oban.Pro.Workflow
    alias Oban.Pro.Workflow.Compensation

    defmodule ChargeCard do
      @behaviour Oban.Pro.Workflow

      use Oban.Pro.Worker

      @impl Oban.Pro.Worker
      def process(_job), do: :ok

      @impl Oban.Pro.Workflow
      def compensate(_job), do: :ok
    end

    defmodule ShipOrder do
      use Oban.Pro.Worker

      @impl Oban.Pro.Worker
      def process(_job), do: :ok
    end

    def insert_saga!(conf, opts \\ []) do
      name = Keyword.get(opts, :name, "payment-saga")
      policy = Keyword.get(opts, :compensate_on, [:discarded])

      workflow =
        [workflow_name: name, compensate_on: policy]
        |> Workflow.new()
        |> Workflow.add(:charge, ChargeCard.new(%{}))
        |> Workflow.add(:ship, ShipOrder.new(%{}), deps: [:charge])

      jobs = Oban.insert_all(conf.name, workflow)

      %{id: workflow.id, compensation_id: nil, jobs: Map.new(jobs, &{&1.meta["name"], &1})}
    end

    def insert_failed_saga!(conf, opts \\ []) do
      saga = insert_saga!(conf, opts)

      put_job_state!(conf, saga.jobs["charge"].id, "completed")
      put_job_state!(conf, saga.jobs["ship"].id, "discarded")

      saga
    end

    def insert_compensated_saga!(conf, opts \\ []) do
      saga = insert_failed_saga!(conf, opts)

      {:compensated, compensation_id} = Compensation.materialize(saga.id, conf)

      %{saga | compensation_id: compensation_id}
    end

    def finish_compensation!(conf, %{compensation_id: compensation_id}, state) do
      query = where(Job, [j], j.meta["workflow_id"] == ^compensation_id)

      Repo.update_all(conf, query, set: [state: state])

      :ok
    end

    def compensation_steps(conf, %{compensation_id: compensation_id}) do
      query =
        Job
        |> where([j], j.meta["workflow_id"] == ^compensation_id)
        |> order_by([j], asc: j.id)

      Repo.all(conf, query)
    end

    defp put_job_state!(conf, job_id, state) do
      Repo.update_all(conf, where(Job, id: ^job_id), set: [state: state])
    end
  end
end
