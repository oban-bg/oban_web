defmodule Oban.Web.CronQuery do
  @moduledoc false

  import Ecto.Query

  alias Oban.Cron.Expression
  alias Oban.{Job, Met, Repo}
  alias Oban.Web.Cron

  def all_crons(params, conf) do
    {sort_by, sort_dir} = parse_sort(params)

    # TODO: Cache these values and avoid running the query too frequently
    crontab = Met.crontab(conf.name)

    history =
      crontab
      |> Enum.map(&elem(&1, 1))
      |> crontab_history(conf)

    crontab
    |> Enum.map(&new(&1, history))
    |> Enum.sort_by(&order(&1, sort_by), sort_dir)
  end

  # Construction

  defp new({expr, worker, opts}, history) do
    fields = [
      expression: expr,
      worker: worker,
      opts: opts,
      next_at: next_at(expr),
      last_at: last_at(history, worker),
      last_state: get_in(history, [worker, :state])
    ]

    struct!(Cron, fields)
  end

  # TODO: Correctly handle jobs with different args
  # TODO: Support mysql/sqlite
  defp crontab_history(workers, conf) do
    query =
      from(
        f in fragment("json_array_elements_text(?)", ^workers),
        as: :list,
        inner_lateral_join:
          j in subquery(
            Job
            |> select(~w(state attempted_at cancelled_at completed_at discarded_at scheduled_at)a)
            |> where([j], j.worker == parent_as(:list).value)
            |> order_by(desc: :id)
            |> limit(1)
          ),
        on: true,
        select:
          {f.value,
           %{
             state: j.state,
             attempted_at: j.attempted_at,
             cancelled_at: j.cancelled_at,
             completed_at: j.completed_at,
             discarded_at: j.discarded_at,
             scheduled_at: j.scheduled_at
           }}
      )

    conf
    |> Repo.all(query)
    |> Map.new()
  end

  defp last_at(history, worker) do
    case Map.get(history, worker) do
      %{state: state, scheduled_at: at} when state in ~w(available scheduled retryable) -> at
      %{state: "executing", attempted_at: at} -> at
      %{state: "cancelled", cancelled_at: at} -> at
      %{state: "completed", completed_at: at} -> at
      %{state: "discarded", discarded_at: at} -> at
      _ -> nil
    end
  end

  defp next_at(expression) do
    expression
    |> Expression.parse!()
    |> Expression.next_at()
  end

  # Sorting

  defp parse_sort(%{sort_by: "last_run", sort_dir: dir}) do
    {:last_run, {String.to_existing_atom(dir), DateTime}}
  end

  defp parse_sort(%{sort_by: "next_run", sort_dir: dir}) do
    {:next_run, {String.to_existing_atom(dir), DateTime}}
  end

  defp parse_sort(%{sort_by: sby, sort_dir: dir}) do
    {String.to_existing_atom(sby), String.to_existing_atom(dir)}
  end

  defp parse_sort(_params), do: {:worker, :asc}

  defp order(%{last_at: nil}, :last_run), do: ~U[2000-01-01 00:00:00Z]
  defp order(%{last_at: last_at}, :last_run), do: last_at
  defp order(%{next_at: next_at}, :next_run), do: next_at
  defp order(%{expression: expression}, :schedule), do: expression
  defp order(%{worker: worker}, :worker), do: worker
end
