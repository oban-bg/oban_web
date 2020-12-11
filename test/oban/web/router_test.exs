defmodule Oban.Web.RouterTest do
  use ExUnit.Case, async: true

  alias Oban.Web.Router

  describe "__options__" do
    test "setting default options in the router module" do
      options = Router.__options__([])

      assert options[:as] == :oban_dashboard
      assert options[:layout] == {Oban.Web.LayoutView, "app.html"}
      assert options[:session] == {Router, :__session__, [Oban, "websocket", 1]}
    end

    test "passing the transport through to the session" do
      assert %{"transport" => "longpoll"} = options_to_session(transport: "longpoll")
    end

    test "passing the default_refresh through to the session" do
      assert %{"refresh" => 5} = options_to_session(default_refresh: 5)
    end

    test "validating oban name values" do
      assert_raise ArgumentError, ~r/invalid :oban_name/, fn ->
        Router.__options__(oban_name: "MyApp.Oban")
      end
    end

    test "validating default_refresh values" do
      assert_raise ArgumentError, ~r/invalid :default_refresh/, fn ->
        Router.__options__(default_refresh: 3)
      end
    end

    test "validating transport values" do
      assert_raise ArgumentError, ~r/invalid :transport/, fn ->
        Router.__options__(transport: "webpoll")
      end
    end
  end

  defp options_to_session(opts) do
    {Router, :__session__, session_opts} =
      opts
      |> Router.__options__()
      |> Keyword.get(:session)

    apply(Router, :__session__, [nil | session_opts])
  end
end
