defmodule Oban.Web.RouterTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias Oban.Web.Router
  alias Plug.Conn

  defmodule Resolver do
    @behaviour Oban.Web.Resolver

    @impl true
    def resolve_user(conn) do
      conn.private.current_user
    end

    @impl true
    def resolve_access(user) do
      if user.admin? do
        :all
      else
        :read_only
      end
    end

    @impl true
    def resolve_refresh(_user), do: 5
  end

  defmodule PartialResolver do
    @behaviour Oban.Web.Resolver

    @impl true
    def resolve_refresh(_user), do: -1
  end

  describe "__options__" do
    test "setting default options in the router module" do
      {session_name, session_opts, route_opts} = Router.__options__([])

      assert session_name == :oban_dashboard
      assert route_opts[:as] == :oban_dashboard
      assert session_opts[:root_layout] == {Oban.Web.LayoutView, :app}
    end

    test "passing the transport through to the session" do
      assert %{"transport" => "longpoll"} = options_to_session(transport: "longpoll")
    end

    test "passing csp nonce assign keys to the session" do
      assert %{"csp_nonces" => nonces} = options_to_session(csp_nonce_assign_key: nil)

      assert %{img: nil, style: nil, script: nil} = nonces

      assert %{"csp_nonces" => %{img: "abc", style: "abc", script: "abc"}} =
               :get
               |> conn("/oban")
               |> Plug.Conn.assign(:my_nonce, "abc")
               |> options_to_session(csp_nonce_assign_key: :my_nonce)
    end

    test "passing a resolver module through to the session" do
      conn =
        :get
        |> conn("/oban")
        |> Conn.put_private(:current_user, %{id: 1, admin?: false})

      session = options_to_session(conn, resolver: Resolver)

      assert %{"access" => :read_only, "refresh" => 5, "user" => %{id: 1}} = session
    end

    test "falling back to default values with a partial resolver implementation" do
      conn =
        :get
        |> conn("/oban")
        |> Conn.put_private(:current_user, %{id: 1, admin?: false})

      session = options_to_session(conn, resolver: PartialResolver)

      assert %{"access" => :all, "refresh" => -1, "user" => nil} = session
    end

    test "validating oban name values" do
      assert_raise ArgumentError, ~r/invalid :oban_name/, fn ->
        Router.__options__(oban_name: "MyApp.Oban")
      end
    end

    test "validating transport values" do
      assert_raise ArgumentError, ~r/invalid :transport/, fn ->
        Router.__options__(transport: "webpoll")
      end
    end

    test "validating resolve_user values" do
      assert_raise ArgumentError, ~r/invalid :resolver/, fn ->
        Router.__options__(resolver: nil)
      end
    end
  end

  defp options_to_session(opts) do
    :get
    |> conn("/oban")
    |> options_to_session(opts)
  end

  defp options_to_session(conn, opts) do
    {_name, sess_opts, _opts} = Router.__options__(opts)

    {Router, :__session__, session_opts} = Keyword.get(sess_opts, :session)

    apply(Router, :__session__, [conn | session_opts])
  end
end
