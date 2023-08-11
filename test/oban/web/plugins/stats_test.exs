defmodule Oban.Web.Plugins.StatsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Oban.Web.Plugins.Stats

  test "the plugin warns that it is unnecessary and stops immediately" do
    warning =
      capture_io(:stderr, fn ->
        pid = start_supervised!({Stats, []})

        refute Process.whereis(pid)
      end)

    assert warning =~ "remove it from your plugins"
  end
end
