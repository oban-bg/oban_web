defmodule Oban.Web.CacheTest do
  use Oban.Web.Case, async: true

  alias Oban.Web.Cache, as: Cache

  @name CacheTest

  describe "fetch/2" do
    setup do
      Process.put(:cache_enabled, true)

      :ok
    end

    test "fetching values from the cache" do
      start_supervised!({Cache, name: @name})

      assert :old_data = Cache.fetch(@name, :key, fn -> :old_data end)
      assert :old_data = Cache.fetch(@name, :key, fn -> :new_data end)
    end
  end
end
