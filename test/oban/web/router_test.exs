defmodule Oban.Web.RouterTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Router

  test "setting default options in the router module" do
    options = Router.__options__([])

    assert options[:layout] == {Oban.Web.LayoutView, "app.html"}
    assert options[:as] == :oban_dashboard
  end
end
