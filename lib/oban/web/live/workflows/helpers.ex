defmodule Oban.Web.Workflows.Helpers do
  @moduledoc false

  alias Oban.Web.Workflow

  @compensation_worker "Oban.Pro.Workflow.Compensation"

  @failed_states ~w(cancelled discarded)
  @terminal_states ~w(cancelled discarded)

  def compensation_worker, do: @compensation_worker

  def compensation?(%Workflow{meta: %{"origin_id" => origin_id}}), do: is_binary(origin_id)
  def compensation?(_workflow), do: false

  def origin_id(%Workflow{meta: %{"origin_id" => origin_id}}) when is_binary(origin_id) do
    origin_id
  end

  def origin_id(_workflow), do: nil

  def compensation_policy(%Workflow{meta: %{"compensate_on" => [_ | _] = policy}}), do: policy
  def compensation_policy(_workflow), do: []

  def compensation_status(root, compensation \\ nil)

  def compensation_status(%Workflow{}, %Workflow{state: state}) do
    case state do
      "completed" -> :completed
      state when state in @failed_states -> :failed
      _state -> :executing
    end
  end

  def compensation_status(%Workflow{} = root, _compensation) do
    cond do
      is_binary(root.compensation_id) -> :unknown
      compensation_policy(root) == [] -> :none
      is_struct(root.resolved_at, DateTime) -> :not_needed
      root.state in @terminal_states -> :pending
      true -> :armed
    end
  end

  def compensation_label(:armed), do: "Armed"
  def compensation_label(:pending), do: "Pending"
  def compensation_label(:executing), do: "Executing"
  def compensation_label(:completed), do: "Completed"
  def compensation_label(:failed), do: "Failed"
  def compensation_label(:not_needed), do: "Not Needed"
  def compensation_label(:unknown), do: "Unknown"
  def compensation_label(_status), do: "None"

  # Forward jobs don't record whether they were rolled back, so the compensation's own steps are
  # folded back onto the graph nodes they reverse.
  def put_compensated_states(graph_data, []), do: graph_data

  def put_compensated_states(%{jobs: jobs} = graph_data, steps) do
    states =
      for %{state: state, meta: %{"origin_job_id" => origin_id}} <- steps,
          is_integer(origin_id),
          into: %{},
          do: {origin_id, state}

    %{graph_data | jobs: Enum.map(jobs, &put_compensated_state(&1, states))}
  end

  def put_compensated_states(graph_data, _steps), do: graph_data

  defp put_compensated_state(job, states) do
    case Map.fetch(states, job.id) do
      {:ok, state} -> put_in(job.meta["compensated"], state)
      :error -> job
    end
  end

  def display_name(workflow, origin_name \\ nil)

  def display_name(%Workflow{} = workflow, origin_name) do
    cond do
      compensation?(workflow) and is_binary(origin_name) -> origin_name
      compensation?(workflow) -> "Compensation"
      is_binary(workflow.name) -> workflow.name
      true -> workflow.id
    end
  end
end
