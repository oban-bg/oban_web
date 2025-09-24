defmodule Oban.Web.Utils do
  @moduledoc false

  import Ecto.Query

  alias Oban.Repo

  def has_dynamic_cron?(conf) do
    %{name: name, prefix: prefix} = conf

    persistent_cache({:dynamic_cron?, name}, fn ->
      query =
        from("columns")
        |> put_query_prefix("information_schema")
        |> where(table_schema: ^prefix, table_name: "oban_crons", column_name: "expression")
        |> select(true)

      Repo.one(conf, query) == true
    end)
  end

  def persistent_cache(key, fun) when is_function(fun, 0) do
    case :persistent_term.get(key, nil) do
      nil -> tap(fun.(), &:persistent_term.put(key, &1))
      val -> val
    end
  end
end
