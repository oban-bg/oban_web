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
end
