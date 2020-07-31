defmodule Oban.Web.RouterTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Router

  describe "__options__" do
    test "setting default options in the router module" do
      options = Router.__options__([])

      assert options[:layout] == {Oban.Web.LayoutView, "app.html"}
      assert options[:as] == :oban_dashboard
      assert options[:session] == {Router, :__session__, [Oban, "websocket"]}
    end

    test "passing the transport through to the session" do
      options = Router.__options__(transport: "longpoll")

      assert {Router, _, [_, "longpoll"]} = options[:session]
    end

    test "validating transport values" do
      assert_raise ArgumentError, ~r/invalid :transport/, fn ->
        Router.__options__(transport: "webpoll")
      end
    end

    test "validating oban name values" do
      assert_raise ArgumentError, ~r/invalid :oban_name/, fn ->
        Router.__options__(oban_name: "MyApp.Oban")
      end
    end
  end
end
