defmodule Oban.Web.Utils do
  @moduledoc false

  import Ecto.Query

  alias Oban.Repo

  # Oban v2.24 and Pro v1.8 flattened engine, plugin, and service module names. Legacy modules
  # still delegate, and they're valid in a config, so detection maps both names to the new one.
  @renamed %{
    Oban.Plugins.Cron => Oban.Cron,
    Oban.Plugins.Lifeline => Oban.Lifeline,
    Oban.Plugins.Pruner => Oban.Pruner,
    Oban.Plugins.Reindexer => Oban.Reindexer,
    Oban.Pro.Engines.Smart => Oban.Pro.Engine,
    Oban.Pro.Plugins.DynamicCron => Oban.Pro.Cron,
    Oban.Pro.Plugins.DynamicLifeline => Oban.Pro.Lifeline,
    Oban.Pro.Plugins.DynamicPruner => Oban.Pro.Pruner,
    Oban.Pro.Plugins.DynamicQueues => Oban.Pro.Queues
  }

  def engine(%{engine: engine}) when is_atom(engine), do: Map.get(@renamed, engine, engine)

  def pro_engine?(conf), do: engine(conf) == Oban.Pro.Engine

  # Cron moved to Oban.Cron in v2.24 and entry_name/1 isn't delegated from the legacy module.
  if Code.ensure_loaded?(Oban.Cron) and function_exported?(Oban.Cron, :entry_name, 1) do
    def cron_entry_name(entry), do: Oban.Cron.entry_name(entry)
  else
    def cron_entry_name(entry), do: Oban.Plugins.Cron.entry_name(entry)
  end

  def has_crons?(conf), do: has_table?("oban_crons", conf)

  def has_workflows?(conf), do: has_table?("oban_workflows", conf)

  def has_pro? do
    persistent_cache(:pro?, fn -> Code.ensure_loaded?(Oban.Pro) end)
  end

  def persistent_cache(key, fun) when is_function(fun, 0) do
    case :persistent_term.get(key, nil) do
      nil -> tap(fun.(), &:persistent_term.put(key, &1))
      val -> val
    end
  end

  defp has_table?(_table_name, %{engine: Oban.Engines.Dolphin}), do: false
  defp has_table?(_table_name, %{engine: Oban.Engines.Lite}), do: false

  defp has_table?(table_name, conf) do
    %{name: oban_name, prefix: prefix} = conf

    persistent_cache({:table?, oban_name, table_name}, fn ->
      query =
        from("tables")
        |> put_query_prefix("information_schema")
        |> where(table_schema: ^prefix, table_name: ^table_name)
        |> select(true)

      Repo.one(conf, query) == true
    end)
  end
end
