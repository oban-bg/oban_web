defmodule Oban.Web.CronQuery do
  @moduledoc false

  import Ecto.Query

  alias Oban.Cron.Expression
  alias Oban.{Job, Met, Repo}
  alias Oban.Web.{Cron, Search, Utils}

  @compile {:no_warn_undefined, Oban.Pro.Cron}

  @suggest_qualifier [
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

  def filterable, do: ~w(workers states modes)a

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

  # Querying

  def all_crons(params, conf) do
    {sort_by, sort_dir} = parse_sort(params)
    limit = Map.get(params, :limit, 20)

    crontab = static_crontab(conf) ++ dynamic_crontab(conf)

    # TODO: Cache these values and avoid running the query too frequently. Cron jobs are
    # inserted at most once a minute.
    history = crontab_history(crontab, conf)
    conditions = Map.take(params, filterable())

    crontab
    |> Enum.map(&new(&1, history))
    |> Enum.filter(&filter(&1, conditions))
    |> Enum.sort_by(&order(&1, sort_by), sort_dir)
    |> Enum.take(limit)
  end

  # TODO: This should be `get_cron`, and we need better queries. No need to load all the dynamic crons
  # to get the value.
  def find_cron(name, conf) when is_binary(name) do
    crontab = static_crontab(conf) ++ dynamic_crontab(conf)
    history = crontab_history(crontab, conf)

    crontab
    |> Enum.find(fn {_expr, _worker, _opts, cron_name, _dynamic?, _paused?} -> cron_name == name end)
    |> case do
      nil -> nil
      entry -> new(entry, history)
    end
  end

  def refresh_cron(conf, %Cron{name: name}), do: find_cron(name, conf)
  def refresh_cron(conf, name) when is_binary(name), do: find_cron(name, conf)
  def refresh_cron(_conf, nil), do: nil

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

  defp new({expr, worker, opts, name, dynamic?, paused?}, history) do
    fields = [
      name: name,
      expression: expr,
      worker: worker,
      opts: opts,
      dynamic?: dynamic?,
      paused?: paused?,
      next_at: next_at(expr),
      last_at: last_at(history, name),
      last_state: get_in(history, [name, :state])
    ]

    struct!(Cron, fields)
  end

  defmacrop contains_name(meta, value) do
    quote do
      fragment("? @> jsonb_build_object('cron_name', ?)", unquote(meta), unquote(value))
    end
  end

  defp crontab_history(crontab, conf) do
    names = Enum.map(crontab, &elem(&1, 3))
    fields = ~w(state attempted_at cancelled_at completed_at discarded_at scheduled_at)a

    ranked =
      from t in subquery(
             from o in Job,
               where: contains_name(o.meta, parent_as(:list).value),
               select: map(o, ^fields),
               select_merge: %{
                 rn: over(row_number(), partition_by: o.meta["cron_name"], order_by: [desc: o.id])
               }
           ),
           where: t.rn == 1

    query =
      from f in fragment("json_array_elements_text(?)", ^names),
        as: :list,
        left_lateral_join: j in subquery(ranked),
        on: true,
        select: {f.value, map(j, ^fields)}

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
  defp order(%{next_at: next_at}, :next_run), do: next_at
  defp order(%{expression: expression}, :schedule), do: expression
  defp order(%{worker: worker}, :worker), do: worker

  # Filtering

  defp filter(_row, conditions) when conditions == %{}, do: true

  defp filter(row, conditions) when is_map(conditions) do
    Enum.all?(conditions, &filter(row, &1))
  end

  defp filter(cron, {:workers, workers}), do: cron.worker in workers
  defp filter(cron, {:states, states}), do: cron.last_state in states

  defp filter(cron, {:modes, modes}) do
    if(cron.dynamic?, do: "dynamic", else: "static") in modes
  end
end
