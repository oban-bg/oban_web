defmodule Oban.Web.RouterTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Router

  test "setting default options in the router module" do
    assert Router.__options__([]) == [
             layout: {Oban.Web.LayoutView, "app.html"},
             as: :oban_dashboard
           ]
  end
end
