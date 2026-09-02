defmodule Oban.Web.PrunerQuery do
  @moduledoc false

  use Oban.Web.Queryable

  import Oban.Web.Pruners.Helpers, only: [match_pairs: 1, mode_label: 1]

  alias Oban.Period
  alias Oban.Pro.Pruner
  alias Oban.Web.Utils

  @compile {:no_warn_undefined, Oban.Pro.Pruner}

  @default "default"

  # Legacy config generates machine named rules, e.g. `queue-events`, one for every override.
  @legacy_sources [queue: :queue_overrides, state: :state_overrides, worker: :worker_overrides]

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

  # Searching

  @impl Queryable
  def qualifiers do
    [
      names: [
        desc: "pruning rule name",
        example: "names:media",
        suggest: &suggest_names/2
      ],
      queues: [
        desc: "queue the rule matches",
        example: "queues:media",
        suggest: &suggest_queues/2
      ],
      workers: [
        desc: "worker the rule matches",
        example: "workers:MyApp.Worker",
        suggest: &suggest_workers/2
      ],
      states: [
        desc: "job state the rule matches",
        example: "states:discarded",
        suggest: @suggest_state
      ],
      modes: [
        desc: "retention mode (age/len)",
        example: "modes:age",
        suggest: @suggest_mode
      ],
      stats: [
        desc: "a status such as paused",
        example: "stats:paused",
        suggest: @suggest_stat
      ]
    ]
  end

  defp suggest_names(frag, conf) do
    conf
    |> all_rules()
    |> Enum.map(& &1.name)
    |> Search.restrict_suggestions(frag)
  end

  defp suggest_queues(frag, conf), do: suggest_match(frag, conf, :queue)

  defp suggest_workers(frag, conf), do: suggest_match(frag, conf, :worker)

  # Only values that some rule actually matches on are suggested, because filtering by anything
  # else can't narrow the chain.
  defp suggest_match(frag, conf, key) do
    conf
    |> all_rules()
    |> Enum.map(&match_value(&1, key))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Search.restrict_suggestions(frag)
  end

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
    rules
    |> Enum.with_index()
    |> Queryable.refine(__MODULE__, params, default_sort: {:order, :asc})
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

  @impl Queryable
  def order({_rule, index}, :order), do: index
  def order({rule, _index}, :name), do: rule.name
  def order({rule, _index}, :limit), do: rule.limit
  def order({rule, _index}, :retention), do: retention(rule)

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

  @impl Queryable
  def filter({rule, _index}, {:names, names}), do: rule.name in names
  def filter({rule, _index}, {:queues, queues}), do: match_value(rule, :queue) in queues
  def filter({rule, _index}, {:states, states}), do: match_value(rule, :state) in states
  def filter({rule, _index}, {:workers, workers}), do: match_value(rule, :worker) in workers
  def filter({rule, _index}, {:modes, modes}), do: mode_label(rule) in modes
  def filter({rule, _index}, {:stats, stats}), do: Enum.any?(stats, &stat?(rule, &1))

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
