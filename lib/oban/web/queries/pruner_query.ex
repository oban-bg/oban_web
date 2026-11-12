defmodule Oban.Web.PrunerQuery do
  @moduledoc false

  use Oban.Web.Queryable

  import Oban.Web.Pruners.Helpers, only: [match_pairs: 1, mode_label: 1]

  import Ecto.Query

  alias Oban.{Period, Repo}
  alias Oban.Web.{PrunerRule, Utils}

  @default "default"
  @service Oban.Pro.Pruner

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
    if Utils.has_pruners?(conf) do
      {default, rest} =
        PrunerRule
        |> order_by(asc: :position, asc: :name)
        |> then(&Repo.all(conf, &1))
        |> Enum.split_with(&(&1.name == @default))

      rest ++ default
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
  isn't also in the configuration. A pruner is only reported missing for an instance that runs
  queues or plugins of its own, because a dashboard-only instance can't tell what other nodes run.
  """
  def service_status(conf) do
    case Utils.fetch_service(conf, @service) do
      {:ok, {_module, opts}} ->
        %{missing?: false, sync_mode: Keyword.get(opts, :sync_mode, :manual)}

      :error ->
        %{missing?: working?(conf), sync_mode: nil}
    end
  end

  defp working?(%{plugins: plugins, queues: queues}) do
    queues != [] or Enum.any?(plugins, &(&1 != Oban.Met and not match?({Oban.Met, _opts}, &1)))
  end

  @doc """
  Names of the rules declared in the pruner's configuration, rather than created at runtime.
  """
  def configured_names(conf) do
    case Utils.fetch_service(conf, @service) do
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
  Insert a brand new rule after the existing rules, refusing to clobber one with the same name.
  """
  def create_rule(conf, params) do
    changeset = PrunerRule.changeset(Map.put(params, :position, 0))

    Repo.transaction(conf, fn ->
      with :ok <- check_available(conf, changeset),
           {:ok, rule} <- Repo.insert(conf, changeset) do
        reposition(conf, rule.name, nil)
      else
        {:error, reason} -> Repo.rollback(conf, reason)
      end
    end)
  end

  @doc """
  Update a rule's match and retention, refusing when the rule changed since the form opened.
  """
  def update_rule(conf, name, lock_version, params) do
    with {:ok, rule} <- fetch_rule(conf, name) do
      changeset = PrunerRule.changeset(%{rule | lock_version: lock_version}, params)

      Repo.update(conf, changeset, stale_error_field: :lock_version)
    end
  end

  @doc """
  Pause or resume a rule, refusing when the rule changed since it was rendered.
  """
  def toggle_rule(conf, rule, paused?) do
    update_rule(conf, rule.name, rule.lock_version, %{paused: paused?})
  end

  @doc """
  Delete a rule, refusing the default rule and stale copies.
  """
  def delete_rule(_conf, %{name: @default}), do: {:error, ~s(the "default" rule can't be deleted)}

  def delete_rule(conf, rule) do
    with {:ok, stored} <- fetch_rule(conf, rule.name) do
      changeset = PrunerRule.lock_changeset(%{stored | lock_version: rule.lock_version})

      Repo.delete(conf, changeset, stale_error_field: :lock_version)
    end
  end

  @doc """
  Move a rule to a new spot in the evaluation chain.

  Positions renumber the whole chain, so a stale position can't corrupt ordering and no lock
  check is needed.
  """
  def move_rule(_conf, %{name: @default} = rule, _position), do: {:ok, rule}

  def move_rule(conf, rule, position) do
    Repo.transaction(conf, fn ->
      case fetch_rule(conf, rule.name) do
        {:ok, _rule} -> reposition(conf, rule.name, position)
        {:error, reason} -> Repo.rollback(conf, reason)
      end
    end)
  end

  defp check_available(conf, changeset) do
    name = Ecto.Changeset.get_field(changeset, :name)

    if is_binary(name) and Repo.exists?(conf, where(PrunerRule, name: ^name)) do
      {:error, ~s(a rule named "#{name}" already exists)}
    else
      :ok
    end
  end

  defp fetch_rule(conf, name) do
    case Repo.one(conf, where(PrunerRule, name: ^name)) do
      nil -> {:error, :not_found}
      rule -> {:ok, rule}
    end
  end

  defp reposition(conf, name, desired) do
    names =
      PrunerRule
      |> where([r], r.name != @default)
      |> order_by(asc: :position, asc: :name)
      |> lock("FOR UPDATE")
      |> select([r], r.name)
      |> then(&Repo.all(conf, &1))
      |> List.delete(name)

    index = (desired || length(names)) |> max(0) |> min(length(names))

    names
    |> List.insert_at(index, name)
    |> Kernel.++([@default])
    |> Enum.with_index()
    |> Enum.each(fn {rule_name, position} ->
      Repo.update_all(conf, where(PrunerRule, name: ^rule_name), set: [position: position])
    end)

    Repo.one!(conf, where(PrunerRule, name: ^name))
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
