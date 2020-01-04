defmodule ObanWeb.DetailComponentTest do
  use ObanWeb.DataCase

  import Phoenix.LiveViewTest

  alias ObanWeb.DetailComponent, as: Component

  test "rendering job details" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}}

    html = render_component(Component, id: job.id, job: job)

    assert html =~ job.worker
  end
end
