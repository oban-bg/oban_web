defmodule ObanWeb.RouterTest do
  use ExUnit.Case, async: true

  alias ObanWeb.Router

  test "setting default options in the router module" do
    assert Router.__options__([]) == [
             layout: {ObanWeb.LayoutView, "app.html"},
             as: :oban_dashboard
           ]
  end
end
