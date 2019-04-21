defmodule ObanWeb.DashboardLiveTest do
  use ObanWeb.DataCase

  import Phoenix.LiveViewTest

  test "simple mounting" do
    start_supervised!({Oban, repo: ObanWeb.Repo})

    {:ok, _view, html} = mount(ObanWeb.Endpoint, ObanWeb.DashboardLive, session: %{})

    assert html =~ "Executing Jobs"
  end
end
