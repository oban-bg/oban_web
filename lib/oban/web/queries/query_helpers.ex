defmodule Oban.Web.QueryHelpers do
  @moduledoc false

  import Ecto.Query

  alias Oban.Repo

  # Engine Guards

  defguard is_mysql(conf) when conf.engine == Oban.Engines.Dolphin

  defguard is_sqlite(conf) when conf.engine == Oban.Engines.Lite

  # Type Extraction

  defmacro mysql_extract_type(field, path) do
    quote do
      fragment("lower(json_type(json_extract(?, ?)))", unquote(field), unquote(path))
    end
  end

  defmacro sqlite_extract_type(field, path) do
    quote do
      fragment("json_type(?->?)", unquote(field), unquote(path))
    end
  end

  defmacro postgres_extract_type(field, path) do
    quote do
      fragment("jsonb_typeof(?#>?)", unquote(field), unquote(path))
    end
  end

  # Array Containment

  defmacro sqlite_contains_any(column, list) do
    quote do
      fragment(
        """
        exists (
          select 1
          from json_each(?) as t1, json_each(?) as t2
          where t1.value = t2.value
        )
        """,
        unquote(column),
        ^Oban.JSON.encode!(unquote(list))
      )
    end
  end

  # Id Windows

  # MySQL raises an out of bounds error when subtracting from an UNSIGNED value returns a value
  # less than 0. There's no standard `greatest/max` function that can clamp to 0, so we use a case
  # statement instead.
  defmacro subtract_unsigned(id, limit) do
    quote do
      fragment(
        "CASE WHEN ? > ? THEN ? - ? ELSE 1 END",
        unquote(id),
        unquote(limit),
        unquote(id),
        unquote(limit)
      )
    end
  end

  # Restricting a query to the most recent ids bounds scans by the primary key, so filters that
  # lack an index stay cheap. Limits are approximate because ids aren't necessarily contiguous.
  def limit_by_id(source, :infinity, _conf), do: source

  def limit_by_id(source, limit, conf) when is_integer(limit) do
    last_id =
      source
      |> select([j], type(subtract_unsigned(j.id, ^limit), :integer))
      |> order_by(desc: :id)
      |> limit(1)
      |> then(&Repo.one(conf, &1))

    where(source, [j], j.id >= ^(last_id || 0))
  end
end
