defmodule Mix.Tasks.ObanWeb.InstallTest do
  use ExUnit.Case

  import Igniter.Test

  test "installation adds the route the neccessary setup to the router" do
    phx_test_project()
    |> apply_igniter!()
    |> Igniter.compose_task("oban_web.install")
    |> assert_has_patch("lib/test_web/router.ex", """
          ...|
      2  2   |  use TestWeb, :router
      3  3   |
         4 + |  import Oban.Web.Router
         5 + |
      4  6   |  pipeline :browser do
      5  7   |    plug(:accepts, ["html"])
          ...|
     41 43   |      forward("/mailbox", Plug.Swoosh.MailboxPreview)
     42 44   |    end
        45 + |
        46 + |    scope "/" do
        47 + |      pipe_through :browser
        48 + |
        49 + |      oban_dashboard("/oban")
        50 + |    end
     43 51   |  end
     44 52   |end
          ...|
    """)
  end
end
