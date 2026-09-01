defmodule Oban.Web.Pages.Pruners.DetailTest do
  use Oban.Web.Case

  alias Oban.Pro.Pruner

  @moduletag :pro

  test "displaying a rule's match, retention, and evaluation order" do
    live =
      start_pruner_live!(
        rules: [
          [name: "media", queue: "media", state: :completed, max_len: 500, timeout: 15_000],
          [name: "default", max_age: {1, :day}]
        ],
        rule: "media"
      )

    html = render(live)

    assert html =~ "media"
    assert html =~ "completed"
    assert html =~ "500 jobs"
    assert html =~ "15s"
    assert html =~ "1 of 2"
  end

  test "listing the whole evaluation chain" do
    live =
      start_pruner_live!(
        rules: [
          [name: "media", queue: "media", max_len: 500],
          [name: "audit", worker: "MyApp.Audit", max_age: {90, :days}],
          [name: "default", max_age: {1, :day}]
        ],
        rule: "audit"
      )

    chain = live |> element("#pruner-chain") |> render()

    assert chain =~ "media"
    assert chain =~ "audit"
    assert chain =~ "default"

    assert has_element?(live, ~s(#chain-audit[aria-current="true"]))
    refute has_element?(live, ~s(#chain-media[aria-current="true"]))
  end

  test "moving to another rule from the chain" do
    live =
      start_pruner_live!(
        rules: [
          [name: "media", queue: "media", max_len: 500],
          [name: "default", max_age: :infinity]
        ],
        rule: "media"
      )

    live
    |> element("#chain-default")
    |> render_click()

    assert_patch(live, "/oban/pruners/default")

    assert has_element?(live, ~s(#chain-default[aria-current="true"]))

    html = render(live)

    assert html =~ "Every completed, cancelled, and discarded job"
    assert html =~ "Forever"

    assert live |> element("#detail-delete") |> render() =~ "disabled"
  end

  test "warning about a rule that earlier rules already claim" do
    live =
      start_pruner_live!(
        rules: [
          [name: "retained", queue: "media", max_age: :infinity],
          [name: "trimmed", queue: "media", state: :completed, max_len: 100]
        ],
        rule: "trimmed"
      )

    assert live |> element("#pruner-shadowed-note") |> render() =~ "retained"
    assert live |> element("#chain-retained") |> render() =~ ~s(rel="is-shadowing")
  end

  test "leaving rules unmarked when earlier rules are paused or only partly overlap" do
    live =
      start_pruner_live!(
        rules: [
          [name: "retained", queue: "media", max_age: :infinity, paused: true],
          [name: "cancellations", queue: "media", state: :cancelled, max_len: 100],
          [name: "trimmed", queue: "media", state: :completed, max_len: 100]
        ],
        rule: "trimmed"
      )

    refute live |> element("#pruner-shadowed-note") |> has_element?()
  end

  test "explaining that a paused rule falls through to later rules" do
    live =
      start_pruner_live!(
        rules: [[name: "media", queue: "media", max_len: 500, paused: true]],
        rule: "media"
      )

    assert live |> element("#pruner-paused-note") |> render() =~ "fall through"
  end

  test "pausing and resuming a rule from the drawer" do
    live =
      start_pruner_live!(rules: [[name: "media", queue: "media", max_len: 500]], rule: "media")

    live |> element("#detail-pause-resume") |> render_click()

    assert live |> element("#status-paused") |> has_element?()
    assert render(live) =~ "Rule &quot;media&quot; paused"
    assert %{paused: true} = Pruner.get("media")

    live |> element("#detail-pause-resume") |> render_click()

    refute live |> element("#status-paused") |> has_element?()
    assert render(live) =~ "Rule &quot;media&quot; resumed"
    assert %{paused: false} = Pruner.get("media")
  end

  test "deleting a rule from the drawer" do
    live =
      start_pruner_live!(rules: [[name: "media", queue: "media", max_len: 500]], rule: "media")

    live |> element("#detail-delete") |> render_click()

    assert_patch(live, "/oban/pruners")
    assert render(live) =~ "Rule &quot;media&quot; deleted"
    assert is_nil(Pruner.get("media"))
  end

  test "refusing to act on a stale copy of a rule" do
    live =
      start_pruner_live!(rules: [[name: "media", queue: "media", max_len: 500]], rule: "media")

    assert {:ok, _rule} = Pruner.update("media", limit: 1_000)

    live |> element("#detail-pause-resume") |> render_click()

    assert render(live) =~ "changed elsewhere"
    assert %{paused: false} = Pruner.get("media")
  end

  test "returning to the index when a rule is deleted" do
    live =
      start_pruner_live!(rules: [[name: "media", queue: "media", max_len: 500]], rule: "media")

    assert {:ok, _rule} = Pruner.delete("media")

    send(live.pid, :refresh)

    assert_patch(live, "/oban/pruners")
  end

  describe "read only access" do
    test "disabling every mutating control" do
      live =
        start_pruner_live!(
          rules: [[name: "media", queue: "media", max_len: 500]],
          rule: "media",
          prefix: "/oban-readonly"
        )

      assert live |> element("#detail-pause-resume") |> render() =~ "disabled"
      assert live |> element("#detail-delete") |> render() =~ "disabled"

      assert has_element?(live, "#pruner-form-fields[disabled]")
    end
  end

  defp start_pruner_live!(opts) do
    {name, opts} = Keyword.pop!(opts, :rule)
    {prefix, opts} = Keyword.pop(opts, :prefix, "/oban")

    oban = start_supervised_oban!(engine: Oban.Pro.Engine, plugins: [{Pruner, opts}])

    oban
    |> Oban.Registry.whereis({:plugin, Pruner})
    |> :sys.get_state()

    {:ok, live, _html} = live(build_conn(), "#{prefix}/pruners/#{name}")

    live
  end
end
