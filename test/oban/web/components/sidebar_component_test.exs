defmodule Oban.Web.SidebarComponentTest do
  use Oban.Web.DataCase, async: true

  import Phoenix.LiveViewTest

  alias Oban.Config
  alias Oban.Web.SidebarComponent, as: Component

  setup do
    Process.put(:routing, :nowhere)

    :ok
  end

  test "displaying summarized queue details" do
    gossip = [
      build_gossip(queue: "alpha", node: "web.1", global_limit: 8),
      build_gossip(queue: "alpha", node: "web.2", global_limit: 8),
      build_gossip(queue: "gamma", node: "web.1", local_limit: 5),
      build_gossip(queue: "gamma", node: "web.2", local_limit: 5, paused: true)
    ]

    html = render_component(Component, assigns(gossip: gossip), router: Router)

    assert has_fragment?(html, "#queue-alpha [rel=limit]", 8)
    assert has_fragment?(html, "#queue-alpha [rel=is-global]")
    refute has_fragment?(html, "#queue-alpha [rel=is-paused]")

    assert has_fragment?(html, "#queue-gamma [rel=limit]", 10)
    refute has_fragment?(html, "#queue-gamma [rel=is-global]")
    assert has_fragment?(html, "#queue-gamma [rel=is-paused]")
  end

  defp assigns(opts) do
    [conf: Config.new(repo: Repo), id: :sidebar, page: :jobs, sections: [:queues]]
    |> Keyword.put(:counts, [counts()])
    |> Keyword.put(:gossip, [])
    |> Keyword.put(:params, %{})
    |> Keyword.merge(opts)
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
end
