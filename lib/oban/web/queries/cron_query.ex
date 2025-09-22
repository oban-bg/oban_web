defmodule Oban.Web.CronQuery do
  @moduledoc false

  import Ecto.Query

  alias Oban.Cron.Expression
  alias Oban.{Job, Met, Repo}
  alias Oban.Web.Cron

  def all_crons(_params, conf) do
    # TODO: Cache these values and avoid running the query too frequently
    crontab = Met.crontab(conf.name)
    workers = Enum.map(crontab, &elem(&1, 1))
    history = crontab_history(workers, conf)

    for {expr, worker, opts} <- crontab do
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
  end

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
end
