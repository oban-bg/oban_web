defmodule Oban.Web.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias Oban.Web.Router
  alias Plug.Conn

  describe "__options__" do
    test "setting default options in the router module" do
      options = Router.__options__([])

      assert options[:as] == :oban_dashboard
      assert options[:layout] == {Oban.Web.LayoutView, "app.html"}
      assert options[:session] == {Router, :__session__, [Oban, "websocket", 1, &Router.__resolve_user__/1]}
    end

    test "passing the transport through to the session" do
      assert %{"transport" => "longpoll"} = options_to_session(transport: "longpoll")
    end

    test "passing the default_refresh through to the session" do
      assert %{"refresh" => 5} = options_to_session(default_refresh: 5)
    end

    test "passing an anonymous resolve_user function through to the session" do
      resolve_user = fn _conn -> %{id: 1} end

      assert %{"user" => %{id: 1}} = options_to_session(resolve_user: resolve_user)
    end

    test "passing a resolve_user function capture through to the session" do
      defmodule Resolver do
        def call(conn) do
          conn.private.current_user
        end
      end

      conn =
        :get
        |> conn("/oban")
        |> Conn.put_private(:current_user, %{id: 1})

      assert %{"user" => %{id: 1}} = options_to_session(conn, resolve_user: &Resolver.call/1)
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

    test "validating resolve_user values" do
      assert_raise ArgumentError, ~r/invalid :resolve_user/, fn ->
        Router.__options__(resolve_user: fn -> nil end)
      end
    end
  end

  defp options_to_session(opts) do
    :get
    |> conn("/oban")
    |> options_to_session(opts)
  end

  defp options_to_session(conn, opts) do
    {Router, :__session__, session_opts} =
      opts
      |> Router.__options__()
      |> Keyword.get(:session)

    apply(Router, :__session__, [conn | session_opts])
  end
end
