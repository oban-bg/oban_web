defmodule Oban.Web.Utils do
  @moduledoc false

  import Ecto.Query

  alias Oban.Repo

  def has_crons?(conf), do: has_table?(conf, "oban_crons")

  def has_workflows?(conf), do: has_table?(conf, "oban_workflows")

  def has_pro? do
    persistent_cache(:pro?, fn -> Code.ensure_loaded?(Oban.Pro) end)
  end

  def persistent_cache(key, fun) when is_function(fun, 0) do
    case :persistent_term.get(key, nil) do
      nil -> tap(fun.(), &:persistent_term.put(key, &1))
      val -> val
    end
  end

  defp has_table?(conf, table_name) do
    %{name: name, prefix: prefix} = conf

    persistent_cache({:table?, name, table_name}, fn ->
      query =
        from("tables")
        |> put_query_prefix("information_schema")
        |> where(table_schema: ^prefix, table_name: ^table_name)
        |> select(true)

      Repo.one(conf, query) == true
    end)
  end
end
