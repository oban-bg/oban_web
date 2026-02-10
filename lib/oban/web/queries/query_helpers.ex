defmodule Oban.Web.QueryHelpers do
  @moduledoc false

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
end
