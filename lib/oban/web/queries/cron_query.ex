defmodule Oban.Web.CronQuery do
  @moduledoc false

  use Oban.Web.Queryable

  import Ecto.Query
  import Oban.Web.QueryHelpers

  alias Oban.Cron.Expression
  alias Oban.{Job, Met, Repo}
  alias Oban.Web.{Cron, CronEntry, Utils}

  @suggest_state [
    {"available", "last job is available", "available"},
    {"cancelled", "last job was cancelled", "cancelled"},
    {"completed", "last job was completed", "completed"},
    {"discarded", "last job was discarded", "discarded"},
    {"executing", "last job is executing", "executing"},
    {"retryable", "last job is retryable", "retryable"},
    {"scheduled", "last job is scheduled", "scheduled"},
    {"unknown", "no previous jobs available", "unknown"}
  ]

  @suggest_mode [
    {"static", "regular cron job", "static"},
    {"dynamic", "dynamic cron job", "dynamic"}
  ]

  # Searching

  @impl Queryable
  def qualifiers do
    [
      names: [
        desc: "cron entry name",
        example: "names:my-cron",
        suggest: &suggest_names/2
      ],
      workers: [
        desc: "cron worker name",
        example: "workers:MyApp.Worker",
        suggest: &suggest_workers/2
      ],
      modes: [
        desc: "cron mode (static/dynamic)",
        example: "modes:static",
        suggest: @suggest_mode
      ],
      states: [
        desc: "last execution state",
        example: "states:completed",
        suggest: @suggest_state,
        parse: &parse_states/1
      ]
    ]
  end

  defp suggest_names(frag, conf) do
    static_names =
      conf.name
      |> Met.crontab()
      |> Enum.map(&entry_name/1)

    dynamic_names =
      if Utils.has_crons?(conf) do
        query = from c in CronEntry, select: c.name
        Repo.all(conf, query)
      else
        []
      end

    Search.restrict_suggestions(static_names ++ dynamic_names, frag)
  end

  defp suggest_workers(frag, conf) do
    conf.name
    |> Met.crontab()
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(&to_string/1)
    |> Search.restrict_suggestions(frag)
  end

  defp parse_states(states) do
    states
    |> String.split(",")
    |> Enum.map(fn
      "unknown" -> nil
      state -> state
    end)
  end

  @history_limit 60

  # Querying

  def all_crons(params, conf) do
    crontab = static_crontab(conf) ++ dynamic_crontab(conf)
    history = crontab_history(crontab, conf)

    crontab
    |> Enum.map(&build_cron(&1, history))
    |> Queryable.refine(__MODULE__, params, default_sort: {:worker, :asc}, limit: 20)
  end

  def get_cron(name, conf) when is_binary(name) do
    with entry when not is_nil(entry) <- find_cron_entry(name, conf) do
      history = cron_history(name, conf)
      build_cron(entry, %{name => history})
    end
  end

  defp find_cron_entry(name, conf) do
    static_entry =
      conf
      |> static_crontab()
      |> Enum.find(fn {_, _, _, cron_name, _, _} -> cron_name == name end)

    cond do
      static_entry ->
        static_entry

      Utils.has_crons?(conf) ->
        query =
          from c in CronEntry,
            where: c.name == ^name,
            select: {c.expression, c.worker, c.opts, c.name, true, c.paused},
            limit: 1

        Repo.one(conf, query)

      true ->
        nil
    end
  end

  def cron_history(name, conf) do
    query =
      Job
      |> where(^filter_cron_name(name, conf))
      |> order_by([j], desc: j.id)
      |> limit(@history_limit)
      |> select([j], %{
        state: j.state,
        scheduled_at: j.scheduled_at,
        attempted_at: j.attempted_at,
        finished_at:
          type(
            fragment("COALESCE(?, ?, ?)", j.completed_at, j.cancelled_at, j.discarded_at),
            :utc_datetime_usec
          )
      })

    conf
    |> Repo.all(query)
    |> Enum.reverse()
  end

  defp filter_cron_name(name, conf) when is_mysql(conf) or is_sqlite(conf) do
    dynamic([j], fragment("json_extract(?, '$.cron_name') = ?", j.meta, ^name))
  end

  defp filter_cron_name(name, _conf) do
    dynamic([j], fragment("? @> ?", j.meta, ^%{cron_name: name}))
  end

  defp static_crontab(conf) do
    conf.name
    |> Met.crontab()
    |> Enum.map(fn {expr, worker, opts} = entry ->
      {expr, worker, opts, entry_name(entry), false, false}
    end)
  end

  defp entry_name({_expr, _worker, opts} = entry) do
    Map.get_lazy(opts, "name", fn -> Utils.cron_entry_name(entry) end)
  end

  defp dynamic_crontab(conf) do
    if Utils.has_crons?(conf) do
      query = select(CronEntry, [c], {c.expression, c.worker, c.opts, c.name, true, c.paused})

      Repo.all(conf, query)
    else
      []
    end
  end

  # Construction

  defp build_cron({expr, worker, opts, name, dynamic?, paused?}, history) do
    jobs = Map.get(history, name, [])
    last_job = List.last(jobs)

    fields = [
      name: name,
      expression: expr,
      worker: worker,
      opts: opts,
      dynamic?: dynamic?,
      paused?: paused?,
      next_at: next_at(expr),
      last_at: last_at_from_job(last_job),
      last_state: if(last_job, do: last_job.state),
      history: jobs
    ]

    struct!(Cron, fields)
  end

  defp last_at_from_job(nil), do: nil
  defp last_at_from_job(%{finished_at: at}) when not is_nil(at), do: at
  defp last_at_from_job(%{attempted_at: at}) when not is_nil(at), do: at
  defp last_at_from_job(%{scheduled_at: at}) when not is_nil(at), do: at
  defp last_at_from_job(_job), do: nil

  def crontab_history(crontab, conf) when is_mysql(conf) or is_sqlite(conf) do
    crontab
    |> Enum.map(&elem(&1, 3))
    |> Map.new(fn name -> {name, cron_history(name, conf)} end)
  end

  def crontab_history(crontab, conf) do
    names = Enum.map(crontab, &elem(&1, 3))

    inside =
      from o in Job,
        where:
          fragment("? @> jsonb_build_object('cron_name', ?)", o.meta, parent_as(:list).value),
        order_by: [desc: o.id],
        limit: @history_limit,
        select: %{
          cron_name: o.meta["cron_name"],
          state: o.state,
          attempted_at: o.attempted_at,
          scheduled_at: o.scheduled_at,
          finished_at:
            type(
              fragment("COALESCE(?, ?, ?)", o.completed_at, o.cancelled_at, o.discarded_at),
              :utc_datetime_usec
            )
        }

    query =
      from f in fragment("(SELECT value FROM json_array_elements_text(?) AS t(value))", ^names),
        as: :list,
        left_lateral_join: j in subquery(inside),
        on: true,
        select: {f.value, j}

    conf
    |> Repo.all(query)
    |> Enum.group_by(&elem(&1, 0), fn {_name, job} -> job end)
    |> Map.new(fn {name, jobs} ->
      {name, jobs |> Enum.reject(&empty_job?/1) |> Enum.reverse()}
    end)
  end

  defp empty_job?(nil), do: true
  defp empty_job?(%{scheduled_at: nil}), do: true
  defp empty_job?(_job), do: false

  defp next_at(expression) do
    expression
    |> Expression.parse!()
    |> Expression.next_at()
  end

  # Sorting

  @impl Queryable
  def sorter(sort_by, dir) when sort_by in [:last_run, :next_run], do: {dir, NaiveDateTime}
  def sorter(_sort_by, dir), do: dir

  @impl Queryable
  def order(%{last_at: nil}, :last_run), do: ~U[2000-01-01 00:00:00Z]
  def order(%{last_at: last_at}, :last_run), do: last_at
  def order(%{name: name}, :name), do: name
  def order(%{next_at: next_at}, :next_run), do: next_at
  def order(%{expression: expression}, :schedule), do: expression
  def order(%{worker: worker}, :worker), do: worker

  # Filtering

  @impl Queryable
  def filter(cron, {:names, names}), do: cron.name in names
  def filter(cron, {:workers, workers}), do: cron.worker in workers
  def filter(cron, {:states, states}), do: cron.last_state in states

  def filter(cron, {:modes, modes}) do
    if(cron.dynamic?, do: "dynamic", else: "static") in modes
  end
end
