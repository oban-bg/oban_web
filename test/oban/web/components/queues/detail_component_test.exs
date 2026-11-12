defmodule Oban.Web.Queues.DetailComponentTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  alias Oban.Config
  alias Oban.Engines.Basic
  alias Oban.Web.Queues.DetailComponent, as: Component

  @queue "alpha"

  setup do
    Process.put(:routing, :nowhere)

    {:ok, oban: start_supervised_oban!()}
  end

  @tag :pro
  test "restricting actions based on access", %{oban: oban} do
    conf = Config.new(name: oban, repo: Repo)

    html =
      render_component(Component, assigns(oban, access: :read_only, conf: conf), router: Router)

    assert has_fragment?(html, "[name=local_limit][disabled]")
    assert has_fragment?(html, "[name=global_allowed][disabled]")
    assert has_fragment?(html, "[name=rate_allowed][disabled]")

    html = render_component(Component, assigns(oban, access: :all, conf: conf), router: Router)

    refute has_fragment?(html, "[name=local_limit][disabled]")
  end

  test "listing all queue instances", %{oban: oban} do
    checks = [
      build_gossip(queue: @queue, node: "web.1", name: "Oban"),
      build_gossip(queue: @queue, node: "web.1", name: "Private"),
      build_gossip(queue: @queue, node: "web.2", name: "Oban")
    ]

    html = render_component(Component, assigns(oban, checks: checks), router: Router)

    assert html =~ "web.1/oban"
    assert html =~ "web.1/private"
    assert html =~ "web.2/oban"
  end

  test "disabling advanced features without a producers table", %{oban: oban} do
    conf = Config.new(engine: Basic, name: oban, prefix: "missing", repo: Repo)
    html = render_component(Component, assigns(oban, conf: conf), router: Router)

    assert has_fragment?(html, "#global-form [rel=requires-pro]")
    assert has_fragment?(html, "#rate-limit-form [rel=requires-pro]")
    refute has_fragment?(html, "[name=global_allowed]")
    refute has_fragment?(html, "[name=rate_allowed]")
  end

  @tag :pro
  test "enabling advanced features with a producers table, whatever the engine", %{oban: oban} do
    conf = Config.new(engine: Basic, name: oban, repo: Repo)
    html = render_component(Component, assigns(oban, conf: conf), router: Router)

    refute has_fragment?(html, "#global-form [rel=requires-pro]")
    refute has_fragment?(html, "#rate-limit-form [rel=requires-pro]")
    assert has_fragment?(html, "[name=global_allowed]")
    assert has_fragment?(html, "[name=rate_allowed]")
  end

  test "displaying status badges based on queue state", %{oban: oban} do
    # Paused badge when all nodes are paused
    checks = [build_gossip(queue: @queue, paused: true)]
    html = render_component(Component, assigns(oban, checks: checks), router: Router)

    assert has_fragment?(html, "#status-paused")
    refute has_fragment?(html, "#status-partial")
    refute has_fragment?(html, "#status-terminating")

    # Partial badge when some nodes are paused
    checks = [
      build_gossip(queue: @queue, node: "web.1", paused: true),
      build_gossip(queue: @queue, node: "web.2", paused: false)
    ]

    html = render_component(Component, assigns(oban, checks: checks), router: Router)

    refute has_fragment?(html, "#status-paused")
    assert has_fragment?(html, "#status-partial")

    # Terminating badge when shutdown has started
    checks = [build_gossip(queue: @queue, shutdown_started_at: DateTime.utc_now())]
    html = render_component(Component, assigns(oban, checks: checks), router: Router)

    assert has_fragment?(html, "#status-terminating")
  end

  test "showing header action buttons", %{oban: oban} do
    html = render_component(Component, assigns(oban, []), router: Router)

    assert has_fragment?(html, "#detail-pause-resume")
    assert has_fragment?(html, "#detail-stop")
  end

  test "restricting header actions based on access", %{oban: oban} do
    html = render_component(Component, assigns(oban, access: :read_only), router: Router)

    assert has_fragment?(html, "#detail-pause-resume[disabled]")
    assert has_fragment?(html, "#detail-stop[disabled]")

    html = render_component(Component, assigns(oban, access: :all), router: Router)

    refute has_fragment?(html, "#detail-pause-resume[disabled]")
    refute has_fragment?(html, "#detail-stop[disabled]")
  end

  defp assigns(oban, opts) do
    [access: :all, conf: Config.new(name: oban, repo: Repo), id: :detail, queue: @queue]
    |> Keyword.put(:counts, [counts()])
    |> Keyword.put(:checks, [build_gossip(queue: @queue)])
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
