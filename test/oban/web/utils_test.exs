defmodule Oban.Web.UtilsTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Utils

  describe "engine/1" do
    test "normalizing legacy engine names" do
      assert Oban.Pro.Engine == Utils.engine(%{engine: Oban.Pro.Engine})
      assert Oban.Pro.Engine == Utils.engine(%{engine: Oban.Pro.Engines.Smart})
      assert Oban.Engines.Basic == Utils.engine(%{engine: Oban.Engines.Basic})
    end
  end

  describe "pro_engine?/1" do
    test "detecting the pro engine through either module name" do
      assert Utils.pro_engine?(%{engine: Oban.Pro.Engine})
      assert Utils.pro_engine?(%{engine: Oban.Pro.Engines.Smart})

      refute Utils.pro_engine?(%{engine: Oban.Engines.Basic})
      refute Utils.pro_engine?(%{engine: Oban.Engines.Lite})
      refute Utils.pro_engine?(%{engine: Oban.Queue.BasicEngine})
    end
  end

  describe "has_pruners?/1" do
    test "short circuiting for adapters without pruner support" do
      refute Utils.has_pruners?(%{engine: Oban.Engines.Lite})
      refute Utils.has_pruners?(%{engine: Oban.Engines.Dolphin})
    end
  end

  describe "has_service?/2" do
    test "detecting services through either module name" do
      assert Utils.has_service?(%{plugins: [Oban.Pro.Cron]}, Oban.Pro.Cron)
      assert Utils.has_service?(%{plugins: [Oban.Pro.Plugins.DynamicCron]}, Oban.Pro.Cron)
      assert Utils.has_service?(%{plugins: [{Oban.Pro.Pruner, []}]}, Oban.Pro.Pruner)

      assert Utils.has_service?(
               %{plugins: [{Oban.Pro.Plugins.DynamicPruner, mode: :max_age}]},
               Oban.Pro.Pruner
             )

      assert Utils.has_service?(%{plugins: [{Oban.Plugins.Cron, crontab: []}]}, Oban.Cron)
      assert Utils.has_service?(%{plugins: [Oban.Plugins.Lifeline]}, Oban.Lifeline)
    end

    test "ignoring unconfigured and disabled services" do
      refute Utils.has_service?(%{plugins: [Oban.Cron]}, Oban.Pro.Cron)
      refute Utils.has_service?(%{plugins: []}, Oban.Pro.Cron)
      refute Utils.has_service?(%{plugins: false}, Oban.Pro.Cron)
    end
  end

  describe "fetch_service/2" do
    test "returning options for configured services" do
      assert {:ok, {Oban.Pro.Pruner, []}} =
               Utils.fetch_service(%{plugins: [Oban.Pro.Pruner]}, Oban.Pro.Pruner)

      assert {:ok, {Oban.Pro.Pruner, sync_mode: :automatic}} =
               Utils.fetch_service(
                 %{plugins: [{Oban.Pro.Plugins.DynamicPruner, sync_mode: :automatic}]},
                 Oban.Pro.Pruner
               )
    end

    test "ignoring unconfigured and disabled services" do
      assert :error = Utils.fetch_service(%{plugins: [Oban.Pro.Cron]}, Oban.Pro.Pruner)
      assert :error = Utils.fetch_service(%{plugins: false}, Oban.Pro.Pruner)
    end
  end
end
