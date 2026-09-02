defmodule Oban.Web.PrunerQuery do
  @moduledoc false

  import Oban.Web.Pruners.Helpers, only: [match_pairs: 1, mode_label: 1]

  alias Oban.Period
  alias Oban.Pro.Pruner
  alias Oban.Web.{Search, Utils}

  @compile {:no_warn_undefined, Oban.Pro.Pruner}

  @default "default"

  # Legacy config generates machine named rules, e.g. `queue-events`, one for every override.
  @legacy_sources [queue: :queue_overrides, state: :state_overrides, worker: :worker_overrides]

  @suggest_qualifier [
    {"names:", "pruning rule name", "names:media"},
    {"queues:", "queue the rule matches", "queues:media"},
    {"workers:", "worker the rule matches", "workers:MyApp.Worker"},
    {"states:", "job state the rule matches", "states:discarded"},
    {"modes:", "retention mode (age/length)", "modes:age"},
    {"stats:", "a status such as paused", "stats:paused"}
  ]

  @suggest_mode [
    {"age", "jobs are retained by age", "age"},
    {"length", "jobs are retained by count", "length"}
  ]

  @suggest_state [
    {"cancelled", "the rule only prunes cancelled jobs", "cancelled"},
    {"completed", "the rule only prunes completed jobs", "completed"},
    {"discarded", "the rule only prunes discarded jobs", "discarded"}
  ]

  @suggest_stat [
    {"active", "the rule is applied while pruning", "active"},
    {"archiving", "the rule archives jobs before deleting", "archiving"},
    {"paused", "the rule is skipped while pruning", "paused"}
  ]

  @known_qualifiers MapSet.new(@suggest_qualifier, fn {qualifier, _, _} -> qualifier end)

  # Searching

  def filterable, do: ~w(modes names queues states stats workers)a

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
          ["queues", frag] -> suggest_match(frag, conf, :queue)
          ["workers", frag] -> suggest_match(frag, conf, :worker)
          ["modes", frag] -> suggest_static(frag, @suggest_mode)
          ["states", frag] -> suggest_static(frag, @suggest_state)
          ["stats", frag] -> suggest_static(frag, @suggest_stat)
          [frag] -> suggest_static(frag, @suggest_qualifier)
          _ -> []
        end
    end
  end

  def append(terms, choice) do
    Search.append(terms, choice, @known_qualifiers)
  end

  def complete(terms, conf) do
    case suggest(terms, conf) do
      [] -> terms
      [{match, _, _} | _] -> append(terms, match)
    end
  end

  defp suggest_static(fragment, possibilities) do
    for {field, _, _} = suggest <- possibilities,
        String.starts_with?(field, fragment),
        do: suggest
  end

  defp suggest_names(fragment, conf) do
    conf
    |> all_rules()
    |> Enum.map(& &1.name)
    |> Search.restrict_suggestions(fragment)
  end

  # Only values that some rule actually matches on are suggested, because filtering by anything
  # else can't narrow the chain.
  defp suggest_match(fragment, conf, key) do
    conf
    |> all_rules()
    |> Enum.map(&match_value(&1, key))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Search.restrict_suggestions(fragment)
  end

  defp parse_term("names:" <> names), do: {:names, String.split(names, ",")}
  defp parse_term("queues:" <> queues), do: {:queues, String.split(queues, ",")}
  defp parse_term("workers:" <> workers), do: {:workers, String.split(workers, ",")}
  defp parse_term("states:" <> states), do: {:states, String.split(states, ",")}
  defp parse_term("modes:" <> modes), do: {:modes, String.split(modes, ",")}
  defp parse_term("stats:" <> stats), do: {:stats, String.split(stats, ",")}
  defp parse_term(_term), do: {:none, ""}

  @doc """
  All persisted rules, in the order the pruner evaluates them.
  """
  def all_rules(conf) do
    if Utils.has_pro?() and Utils.has_pruners?(conf) do
      Pruner.all(conf.name)
    else
      []
    end
  end

  @doc """
  Filter and sort rules for display, leaving the stored evaluation chain untouched.

  Rules are given in evaluation order, and that order is only recoverable from the list itself,
  because the default rule always evaluates last regardless of its position.
  """
  def display_rules(rules, params) do
    {sort_by, sort_dir} = parse_sort(params)
    conditions = Map.take(params, filterable())

    rules
    |> Enum.with_index()
    |> Enum.filter(fn {rule, _index} -> filter(rule, conditions) end)
    |> Enum.sort_by(fn {rule, index} -> order(rule, index, sort_by) end, sort_dir)
    |> Enum.map(fn {rule, _index} -> rule end)
  end

  @doc """
  How the configured pruner applies rules.

  Rules only take effect when a pruner is configured, and automatic syncing deletes any rule that
  isn't also in the configuration.
  """
  def service_status(conf) do
    case Utils.fetch_service(conf, Pruner) do
      {:ok, {_module, opts}} ->
        %{configured?: true, sync_mode: Keyword.get(opts, :sync_mode, :manual)}

      :error ->
        %{configured?: false, sync_mode: nil}
    end
  end

  @doc """
  Names of the rules declared in the pruner's configuration, rather than created at runtime.
  """
  def configured_names(conf) do
    case Utils.fetch_service(conf, Pruner) do
      {:ok, {_module, opts}} ->
        opts
        |> Keyword.get(:rules, legacy_rules(opts))
        |> Enum.map(&Keyword.get(&1, :name))
        |> Enum.reject(&is_nil/1)
        |> MapSet.new(&to_string/1)

      :error ->
        MapSet.new()
    end
  end

  @doc """
  Insert a brand new rule, refusing to clobber an existing one.

  Pro's `insert/2` is an upsert that replaces a same-named rule wholesale and bypasses the
  optimistic lock, so creation checks for the name first.
  """
  def create_rule(conf, opts) do
    name = Keyword.fetch!(opts, :name)

    if is_nil(Pruner.get(conf.name, name)) do
      Pruner.insert(conf.name, opts)
    else
      {:error, ~s(a rule named "#{name}" already exists)}
    end
  end

  @doc """
  Update a rule's match and retention, refusing when the rule changed since the form opened.
  """
  def update_rule(conf, name, lock_version, opts) do
    Pruner.update(conf.name, name, Keyword.put(opts, :lock_version, lock_version))
  end

  @doc """
  Pause or resume a rule, refusing when the rule changed since it was rendered.
  """
  def toggle_rule(conf, rule, paused?) do
    Pruner.update(conf.name, rule.name, paused: paused?, lock_version: rule.lock_version)
  end

  @doc """
  Delete a rule, refusing the default rule and stale copies.
  """
  def delete_rule(conf, rule) do
    Pruner.delete(conf.name, rule.name, lock_version: rule.lock_version)
  end

  @doc """
  Move a rule to a new spot in the evaluation chain.

  Positions renumber the whole chain, so a stale position can't corrupt ordering and no lock
  check is needed.
  """
  def move_rule(conf, rule, position) do
    Pruner.update(conf.name, rule.name, position: position)
  end

  defp legacy_rules(opts) do
    overrides =
      for {source, key} <- @legacy_sources,
          {value, _mode} <- Keyword.get(opts, key, []),
          do: [name: "#{source}-#{value}"]

    if Keyword.has_key?(opts, :mode), do: overrides ++ [[name: @default]], else: overrides
  end

  # Sorting

  defp parse_sort(%{sort_by: sort_by, sort_dir: dir}) do
    {String.to_existing_atom(sort_by), String.to_existing_atom(dir)}
  end

  defp parse_sort(_params), do: {:order, :asc}

  defp order(_rule, index, :order), do: index
  defp order(rule, _index, :name), do: rule.name
  defp order(rule, _index, :limit), do: rule.limit
  defp order(rule, _index, :retention), do: retention(rule)

  # Ages and lengths aren't comparable, so rules group by mode and only then by how much they
  # retain, with infinite retention last.
  defp retention(%{mode: %{kind: kind, value: value}}), do: {kind, retention_value(value)}
  defp retention(_rule), do: {:unknown, :infinity}

  defp retention_value(value) do
    case Integer.parse(value) do
      {seconds, ""} -> seconds
      {value, " " <> unit} -> Period.to_seconds({value, String.to_existing_atom(unit)})
      _other -> :infinity
    end
  end

  # Filtering

  defp filter(_rule, conditions) when conditions == %{}, do: true

  defp filter(rule, conditions) when is_map(conditions) do
    Enum.all?(conditions, &filter(rule, &1))
  end

  defp filter(rule, {:names, names}), do: rule.name in names
  defp filter(rule, {:queues, queues}), do: match_value(rule, :queue) in queues
  defp filter(rule, {:states, states}), do: match_value(rule, :state) in states
  defp filter(rule, {:workers, workers}), do: match_value(rule, :worker) in workers
  defp filter(rule, {:modes, modes}), do: mode_label(rule) in modes
  defp filter(rule, {:stats, stats}), do: Enum.any?(stats, &stat?(rule, &1))

  defp stat?(rule, "active"), do: not rule.paused
  defp stat?(rule, "archiving"), do: rule.archive
  defp stat?(rule, "paused"), do: rule.paused
  defp stat?(_rule, _stat), do: false

  defp match_value(rule, key) do
    rule
    |> match_pairs()
    |> Keyword.get(key)
  end
end
