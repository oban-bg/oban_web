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
    conf
    |> static_crontab()
    |> Kernel.++(dynamic_crontab(conf))
    |> Enum.map(fn {_expr, worker, opts, _name, _dynamic?, _paused?} -> handler(worker, opts) end)
    |> Enum.uniq()
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
    opts = [default_sort: {:name, :asc}, limit: 20]

    crons =
      conf
      |> static_crontab()
      |> Kernel.++(dynamic_crontab(conf))
      |> Enum.map(&build_cron/1)

    if history_refines?(params) do
      crons
      |> Enum.filter(&entry_match?(&1, params))
      |> with_history(conf)
      |> Queryable.refine(__MODULE__, params, opts)
    else
      crons
      |> Queryable.refine(__MODULE__, params, opts)
      |> with_history(conf)
    end
  end

  defp history_refines?(%{sort_by: "last_run"}), do: true
  defp history_refines?(%{states: _states}), do: true
  defp history_refines?(_params), do: false

  defp entry_match?(cron, params) do
    params
    |> Map.take(~w(names workers modes)a)
    |> Enum.all?(&filter(cron, &1))
  end

  defp with_history([], _conf), do: []

  defp with_history(crons, conf) do
    history =
      crons
      |> Enum.map(& &1.name)
      |> crontab_history(conf)

    Enum.map(crons, &put_history(&1, Map.get(history, &1.name, [])))
  end

  def get_cron(name, conf) when is_binary(name) do
    with entry when not is_nil(entry) <- find_cron_entry(name, conf) do
      entry
      |> build_cron()
      |> put_history(cron_history(name, conf))
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

  defp build_cron({expr, worker, opts, name, dynamic?, paused?}) do
    decorated_name = Cron.decorated_name(worker, opts)

    fields = [
      name: name,
      expression: expr,
      worker: worker,
      handler: decorated_name || worker,
      opts: opts,
      decorated?: is_binary(decorated_name),
      dynamic?: dynamic?,
      paused?: paused?,
      next_at: next_at(expr, opts, paused?)
    ]

    struct!(Cron, fields)
  end

  defp put_history(cron, jobs) do
    last_job = List.last(jobs)

    %{
      cron
      | last_at: last_at_from_job(last_job),
        last_state: if(last_job, do: last_job.state),
        history: jobs
    }
  end

  defp handler(worker, opts), do: Cron.decorated_name(worker, opts) || worker

  defp last_at_from_job(nil), do: nil
  defp last_at_from_job(%{finished_at: at}) when not is_nil(at), do: at
  defp last_at_from_job(%{attempted_at: at}) when not is_nil(at), do: at
  defp last_at_from_job(%{scheduled_at: at}) when not is_nil(at), do: at
  defp last_at_from_job(_job), do: nil

  def crontab_history(names, conf) when is_mysql(conf) or is_sqlite(conf) do
    Map.new(names, fn name -> {name, cron_history(name, conf)} end)
  end

  def crontab_history(names, conf) do
    # The `offset: 0` is an optimization fence for Postgres. Without it the planner pulls the
    # subquery up and, lacking stats for the lateral value, walks the primary key backward
    # filtering on `meta` rather than using the GIN index. CockroachDB elides a zero offset.
    matched =
      from o in Job,
        where:
          fragment("? @> jsonb_build_object('cron_name', ?)", o.meta, parent_as(:list).value),
        offset: 0,
        select: %{
          id: o.id,
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

    inside =
      from m in subquery(matched),
        order_by: [desc: m.id],
        limit: @history_limit,
        select: %{
          cron_name: m.cron_name,
          state: m.state,
          attempted_at: m.attempted_at,
          scheduled_at: m.scheduled_at,
          finished_at: m.finished_at
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

  # A paused entry has no next run, and neither does one that only fires at boot. Per-entry
  # timezones ride along in the entry's opts, but the plugin-level timezone never leaves its
  # node, so entries without an override are evaluated in UTC.
  defp next_at(_expression, _opts, true), do: nil

  defp next_at(expression, opts, false) do
    timezone = Map.get(opts, "timezone", "Etc/UTC")

    case Expression.next_at(Expression.parse!(expression), now_in(timezone)) do
      %DateTime{} = next_at -> DateTime.shift_zone!(next_at, "Etc/UTC")
      :unknown -> nil
    end
  end

  # Without a timezone database, which the standalone image doesn't ship, only UTC resolves.
  defp now_in(timezone) do
    case DateTime.now(timezone) do
      {:ok, now} -> now
      {:error, _reason} -> DateTime.utc_now()
    end
  end

  # Sorting

  @impl Queryable
  def sorter(:last_run, dir), do: {dir, NaiveDateTime}
  def sorter(:next_run, dir), do: {dir, DateTime}
  def sorter(_sort_by, dir), do: dir

  @impl Queryable
  def order(%{last_at: nil}, :last_run), do: ~U[2000-01-01 00:00:00Z]
  def order(%{last_at: last_at}, :last_run), do: last_at
  def order(%{next_at: nil}, :next_run), do: ~U[9999-12-31 23:59:59Z]
  def order(%{next_at: next_at}, :next_run), do: next_at
  def order(%{expression: expression}, :schedule), do: cadence(expression)

  # Rows are recognized by their handler, but several entries may share one. Ordering by the
  # entry name second keeps those neighbors in a stable order rather than crontab order.
  def order(%{handler: handler, name: name}, :name), do: {handler, name}

  # Sorting expressions as text puts "*/5 * * * *" beside "0 0 * * *" for no reason a reader
  # could name. The gap between the next two fires orders entries by how often they run instead,
  # and a reboot entry, which has no cadence, sorts after every entry that does.
  defp cadence(expression) do
    parsed = Expression.parse!(expression)

    with %DateTime{} = first <- Expression.next_at(parsed),
         %DateTime{} = second <- Expression.next_at(parsed, first) do
      DateTime.diff(second, first)
    else
      :unknown -> :infinity
    end
  end

  # Filtering

  @impl Queryable
  def filter(cron, {:names, names}), do: cron.name in names
  def filter(cron, {:workers, workers}), do: cron.handler in workers or cron.worker in workers
  def filter(cron, {:states, states}), do: cron.last_state in states

  def filter(cron, {:modes, modes}) do
    if(cron.dynamic?, do: "dynamic", else: "static") in modes
  end
end
