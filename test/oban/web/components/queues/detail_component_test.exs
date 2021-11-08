defmodule Oban.Web.Queues.DetailComponentTest do
  use Oban.Web.DataCase, async: true

  import Phoenix.LiveViewTest

  alias Oban.Config
  alias Oban.Queue.BasicEngine
  alias Oban.Web.Queues.DetailComponent, as: Component
  alias Oban.Web.Test.Router

  test "disabling advanced features when SmartEngine isn't available" do
    conf = Config.new(engine: BasicEngine, repo: Repo)
    assi = [id: :detail, conf: conf, counts: [counts()], gossip: [gossip()], queue: "alpha"]
    html = render_component(Component, assi, router: Router)

    assert has_fragment?(html, "#global-limit-fields [rel=requires-pro]")
    assert has_fragment?(html, "#rate-limit-fields [rel=requires-pro]")

    # Pro isn't available, we check whether the engine isn't the BasicEngine instead
    conf = %{conf | engine: Oban.Web.FakeEngine}
    html = render_component(Component, Keyword.put(assi, :conf, conf), router: Router)

    refute has_fragment?(html, "#global-limit-fields [rel=requires-pro]")
    refute has_fragment?(html, "#rate-limit-fields [rel=requires-pro]")
  end

  defp counts do
    %{
      "name" => "alpha",
      "available" => 0,
      "cancelled" => 0,
      "completed" => 0,
      "discarded" => 0,
      "executing" => 0,
      "retryable" => 0,
      "scheduled" => 0
    }
  end

  defp gossip do
    %{
      "queue" => "alpha",
      "name" => "Oban",
      "node" => "local",
      "running" => [],
      "started_at" => DateTime.to_iso8601(DateTime.utc_now())
    }
  end

  defp has_fragment?(html, selector) do
    fragment =
      html
      |> Floki.parse_fragment!()
      |> Floki.find(selector)

    fragment != []
  end
end
