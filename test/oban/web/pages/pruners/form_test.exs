defmodule Oban.Web.Pages.Pruners.FormTest do
  use Oban.Web.Case

  alias Oban.Pro.Pruner

  @moduletag :pro

  describe "creating" do
    test "opening the form from the index" do
      live = start_pruner_live!(path: "/oban/pruners", rules: [[name: "default", max_len: 1_000]])

      live
      |> element("#new-pruner-button")
      |> render_click()

      assert_patch(live, "/oban/pruners/new")

      assert live |> element("#new-pruner-form") |> has_element?()

      panel = live |> element("#new-pruner-panel") |> render()

      assert panel =~ ~s(role="dialog")
      assert panel =~ ~s(aria-modal="true")
      assert panel =~ ~s(aria-labelledby="new-pruner-title")
    end

    test "creating a rule that retains by age" do
      live = start_pruner_live!(rules: [[name: "default", max_len: 1_000]])

      live
      |> form("#new-pruner-form", %{
        "name" => "exports",
        "queue" => "exports",
        "state" => "completed",
        "kind" => "age",
        "age_value" => "2",
        "age_unit" => "weeks",
        "archive" => "true"
      })
      |> render_submit()

      assert_patch(live, "/oban/pruners")
      assert render(live) =~ "Rule &quot;exports&quot; created"

      rule = Pruner.get("exports")

      assert %{queue: "exports", state: "completed"} = rule.match
      assert %{kind: :max_age, value: "2 weeks"} = rule.mode
      assert rule.archive
    end

    test "creating rules that retain by length or forever" do
      live = start_pruner_live!(rules: [[name: "default", max_len: 1_000]])

      live
      |> form("#new-pruner-form", %{"kind" => "length"})
      |> render_change()

      live
      |> form("#new-pruner-form", %{
        "name" => "mailers",
        "worker" => "MyApp.Mailer",
        "length_value" => "500",
        "limit" => "2500"
      })
      |> render_submit()

      assert_patch(live, "/oban/pruners")

      rule = Pruner.get("mailers")

      assert %{worker: "MyApp.Mailer", queue: nil} = rule.match
      assert %{kind: :max_len, value: "500"} = rule.mode
      assert 2_500 == rule.limit

      render_patch(live, "/oban/pruners/new")

      live
      |> form("#new-pruner-form", %{"kind" => "forever"})
      |> render_change()

      live
      |> form("#new-pruner-form", %{"name" => "audit", "worker" => "MyApp.Audit"})
      |> render_submit()

      assert_patch(live, "/oban/pruners")

      assert %{mode: %{value: "infinity"}} = Pruner.get("audit")
    end

    test "surfacing errors without saving" do
      live = start_pruner_live!(rules: [[name: "media", queue: "media", max_len: 500]])

      live
      |> form("#new-pruner-form", %{"name" => "media", "age_value" => "1"})
      |> render_submit()

      assert live |> element("#new-pruner-errors") |> render() =~ "already exists"
      assert %{mode: %{kind: :max_len}} = Pruner.get("media")

      live
      |> form("#new-pruner-form", %{"name" => "broken", "age_value" => ""})
      |> render_submit()

      assert live |> element("#new-pruner-errors") |> render() =~ "Age must be a positive number"
      assert is_nil(Pruner.get("broken"))
    end
  end

  describe "editing" do
    test "editing a rule seeded from the one being viewed" do
      live =
        start_pruner_live!(
          path: "/oban/pruners/media",
          rules: [[name: "media", queue: "media", max_age: {7, :days}, limit: 2_500]]
        )

      form = live |> element("#pruner-form") |> render()

      assert form =~ ~s(name="queue" value="media")
      assert form =~ ~s(name="age_value" value="7")
      assert form =~ ~s(name="limit" value="2500")

      refute live |> element("#back-link") |> render() =~ "data-confirm-back"

      live
      |> form("#pruner-form", %{"age_value" => "3"})
      |> render_change()

      assert live |> element("#back-link") |> render() =~ "data-confirm-back"
      assert live |> element("#chain-media") |> render() =~ "data-confirm"

      live
      |> form("#pruner-form", %{"age_value" => "3"})
      |> render_submit()

      assert render(live) =~ "Rule &quot;media&quot; updated"
      refute live |> element("#back-link") |> render() =~ "data-confirm-back"

      assert %{mode: %{kind: :max_age, value: "3 days"}} = Pruner.get("media")
    end

    test "editing a rule repeatedly without reopening the page" do
      live =
        start_pruner_live!(
          path: "/oban/pruners/media",
          rules: [[name: "media", queue: "media", state: :completed, max_len: 500]]
        )

      live
      |> form("#pruner-form", %{"length_value" => "400"})
      |> render_submit()

      live
      |> form("#pruner-form", %{"queue" => ""})
      |> render_submit()

      assert %{match: %{queue: nil, state: "completed"}, mode: %{value: "400"}} =
               Pruner.get("media")

      assert {:ok, _rule} = Pruner.update("media", max_len: 250)

      send(live.pid, :refresh)

      assert live |> element("#pruner-form") |> render() =~ ~s(name="length_value" value="250")
    end

    test "recovering when the rule changed since the page loaded" do
      live =
        start_pruner_live!(
          path: "/oban/pruners/media",
          rules: [[name: "media", queue: "media", max_age: {7, :days}]]
        )

      assert {:ok, _rule} = Pruner.update("media", limit: 9_000)

      live
      |> form("#pruner-form", %{"age_value" => "3"})
      |> render_submit()

      assert live |> element("#pruner-form-errors") |> render() =~ "changed elsewhere"
      assert %{mode: %{value: "7 days"}} = Pruner.get("media")

      live
      |> form("#pruner-form", %{"age_value" => "3"})
      |> render_submit()

      assert render(live) =~ "Rule &quot;media&quot; updated"
      assert %{mode: %{value: "3 days"}} = Pruner.get("media")
    end

    test "warning only when editing a rule declared in configuration" do
      live =
        start_pruner_live!(
          path: "/oban/pruners/media",
          rules: [[name: "media", queue: "media", max_len: 500]]
        )

      assert live |> element("#pruner-form-configured") |> render() =~ "declared in your Oban"

      assert {:ok, _rule} = Pruner.insert(name: "events", queue: "events", max_len: 500)

      render_patch(live, "/oban/pruners/events")

      assert live |> element("#pruner-form") |> has_element?()
      refute live |> element("#pruner-form-configured") |> has_element?()
    end
  end

  defp start_pruner_live!(opts) do
    {path, opts} = Keyword.pop(opts, :path, "/oban/pruners/new")

    oban = start_supervised_oban!(engine: Oban.Pro.Engine, plugins: [{Pruner, opts}])

    oban
    |> Oban.Registry.whereis({:plugin, Pruner})
    |> :sys.get_state()

    {:ok, live, _html} = live(build_conn(), path)

    live
  end
end
