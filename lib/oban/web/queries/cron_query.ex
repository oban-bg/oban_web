defmodule Oban.Web.CronQuery do
  @moduledoc false

  import Ecto.Query
  import Oban.Web.QueryHelpers

  alias Oban.Cron.Expression
  alias Oban.{Job, Met, Repo}
  alias Oban.Web.{Cron, Search, Utils}

  @compile {:no_warn_undefined, Oban.Pro.Cron}

  @suggest_qualifier [
    {"names:", "cron entry name", "names:my-cron"},
    {"workers:", "cron worker name", "workers:MyApp.Worker"},
    {"modes:", "cron mode (static/dynamic)", "modes:static"},
    {"states:", "last execution state", "states:completed"}
  ]

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

  @known_qualifiers MapSet.new(@suggest_qualifier, fn {qualifier, _, _} -> qualifier end)

  # Searching

  def filterable, do: ~w(names workers states modes)a

  def parse(terms) when is_binary(terms) do
    Search.parse(terms, &parse_term/1)
  end

  def suggest(terms, conf, _opts \\ []) do
    terms
    |> String.split(~r/\s+(?=([^\"]*\"[^\"]*\")*[^\"]*$)/)
    |> List.last()
    |> to_string()
    |> case do
      "" ->
        @suggest_qualifier

      last ->
        case String.split(last, ":", parts: 2) do
          ["names", frag] -> suggest_names(frag, conf)
          ["workers", frag] -> suggest_workers(frag, conf)
          ["modes", frag] -> suggest_static(frag, @suggest_mode)
          ["states", frag] -> suggest_static(frag, @suggest_state)
          [frag] -> suggest_static(frag, @suggest_qualifier)
          _ -> []
        end
    end
  end

  defp suggest_static(fragment, possibilities) do
    for {field, _, _} = suggest <- possibilities,
        String.starts_with?(field, fragment),
        do: suggest
  end

  defp suggest_names(fragment, conf) do
    static_names =
      conf.name
      |> Met.crontab()
      |> Enum.map(fn entry -> Oban.Plugins.Cron.entry_name(entry) end)

    dynamic_names =
      if Utils.has_dynamic_cron?(conf) do
        query = from c in Oban.Pro.Cron, select: c.name
        Repo.all(conf, query)
      else
        []
      end

    (static_names ++ dynamic_names)
    |> Search.restrict_suggestions(fragment)
  end

  defp suggest_workers(fragment, conf) do
    conf.name
    |> Met.crontab()
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(&to_string/1)
    |> Search.restrict_suggestions(fragment)
  end

  def append(terms, choice) do
    Search.append(terms, choice, @known_qualifiers)
  end

  def complete(terms, conf) do
    case suggest(terms, conf) do
      [] ->
        terms

      [{match, _, _} | _] ->
        append(terms, match)
    end
  end

  defp parse_term("names:" <> names) do
    {:names, String.split(names, ",")}
  end

  defp parse_term("workers:" <> workers) do
    {:workers, String.split(workers, ",")}
  end

  defp parse_term("states:" <> states) do
    parsed =
      states
      |> String.split(",")
      |> Enum.map(fn
        "unknown" -> nil
        state -> state
      end)

    {:states, parsed}
  end

  defp parse_term("modes:" <> modes) do
    {:modes, String.split(modes, ",")}
  end

  defp parse_term(_term), do: {:none, ""}

  @history_limit 60

  # Querying

  def all_crons(params, conf) do
    {sort_by, sort_dir} = parse_sort(params)
    limit = Map.get(params, :limit, 20)

    crontab = static_crontab(conf) ++ dynamic_crontab(conf)
    history = crontab_history(crontab, conf)
    conditions = Map.take(params, filterable())

    crontab
    |> Enum.map(&build_cron(&1, history))
    |> Enum.filter(&filter(&1, conditions))
    |> Enum.sort_by(&order(&1, sort_by), sort_dir)
    |> Enum.take(limit)
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

      Utils.has_dynamic_cron?(conf) ->
        query =
          from c in Oban.Pro.Cron,
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
        finished_at: fragment("COALESCE(?, ?, ?)", j.completed_at, j.cancelled_at, j.discarded_at)
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
      {expr, worker, opts, Oban.Plugins.Cron.entry_name(entry), false, false}
    end)
  end

  defp dynamic_crontab(conf) do
    if Utils.has_dynamic_cron?(conf) do
      query = select(Oban.Pro.Cron, [c], {c.expression, c.worker, c.opts, c.name, true, c.paused})

      Repo.all(conf, query)
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
        select: %{
          cron_name: o.meta["cron_name"],
          state: o.state,
          attempted_at: o.attempted_at,
          scheduled_at: o.scheduled_at,
          finished_at:
            fragment("COALESCE(?, ?, ?)", o.completed_at, o.cancelled_at, o.discarded_at)
        },
        select_merge: %{
          rn: over(row_number(), partition_by: o.meta["cron_name"], order_by: [desc: o.id])
        }

    ranked = from t in subquery(inside), where: t.rn <= @history_limit

    query =
      from f in fragment("json_array_elements_text(?)", ^names),
        as: :list,
        left_lateral_join: j in subquery(ranked),
        on: true,
        order_by: [asc: j.rn],
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

  defp parse_sort(%{sort_by: "last_run", sort_dir: dir}) do
    {:last_run, {String.to_existing_atom(dir), NaiveDateTime}}
  end

  defp parse_sort(%{sort_by: "next_run", sort_dir: dir}) do
    {:next_run, {String.to_existing_atom(dir), NaiveDateTime}}
  end

  defp parse_sort(%{sort_by: sby, sort_dir: dir}) do
    {String.to_existing_atom(sby), String.to_existing_atom(dir)}
  end

  defp parse_sort(_params), do: {:worker, :asc}

  defp order(%{last_at: nil}, :last_run), do: ~U[2000-01-01 00:00:00Z]
  defp order(%{last_at: last_at}, :last_run), do: last_at
  defp order(%{name: name}, :name), do: name
  defp order(%{next_at: next_at}, :next_run), do: next_at
  defp order(%{expression: expression}, :schedule), do: expression
  defp order(%{worker: worker}, :worker), do: worker

  # Filtering

  defp filter(_row, conditions) when conditions == %{}, do: true

  defp filter(row, conditions) when is_map(conditions) do
    Enum.all?(conditions, &filter(row, &1))
  end

  defp filter(cron, {:names, names}), do: cron.name in names
  defp filter(cron, {:workers, workers}), do: cron.worker in workers
  defp filter(cron, {:states, states}), do: cron.last_state in states

  defp filter(cron, {:modes, modes}) do
    if(cron.dynamic?, do: "dynamic", else: "static") in modes
  end
end
