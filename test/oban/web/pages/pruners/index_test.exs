defmodule Oban.Web.Pages.Pruners.IndexTest do
  use Oban.Web.Case

  alias Oban.Pro.Pruner

  @moduletag :pro

  setup do
    start_supervised_oban!(engine: Oban.Pro.Engine)

    {:ok, live, _html} = live(build_conn(), "/oban/pruners")

    {:ok, live: live}
  end

  test "displaying an empty state without any rules", %{live: live} do
    html = refresh(live)

    assert html =~ "No pruning rules"

    live |> element("#empty-new-rule") |> render_click()

    assert_patch(live, "/oban/pruners/new")
  end

  test "displaying rules in evaluation order with their chain positions" do
    live = start_pruner_live!(rules: standard_rules())

    refresh(live)

    table = live |> element("#pruners-table") |> render()

    assert row_at(table, "media") < row_at(table, "audit")
    assert row_at(table, "audit") < row_at(table, "default")

    assert live |> element(~s(#pruner-media [rel="position"])) |> render() =~ "1"
    assert live |> element(~s(#pruner-default [rel="position"])) |> render() =~ "4"

    render_patch(live, pruners_path(sort_by: "name"))

    assert live |> element(~s(#pruner-audit [rel="position"])) |> render() =~ "2"
  end

  test "displaying a rule's match, mode, and limits" do
    live =
      start_pruner_live!(rules: [[name: "app.media", queue: "media", max_len: 500, limit: 5_000]])

    refresh(live)

    media = live |> element("#pruner-app-media") |> render()

    assert media =~ "queue"
    assert media =~ "media"
    assert media =~ "500 jobs"
    assert media =~ "5k"
  end

  test "distinguishing default, archiving, and paused rules" do
    live =
      start_pruner_live!(
        rules: [
          [name: "media", queue: "media", max_len: 500, paused: true],
          [name: "audit", worker: "MyApp.Audit", max_age: {90, :days}, archive: true]
        ]
      )

    refresh(live)

    media = live |> element("#pruner-media") |> render()

    assert media =~ ~s(rel="is-paused")
    refute media =~ ~s(rel="is-archive")

    audit = live |> element("#pruner-audit") |> render()

    assert audit =~ ~s(rel="is-archive")
    assert audit =~ ~s(rel="is-active")

    default = live |> element("#pruner-default") |> render()

    assert default =~ ~s(rel="is-default")
  end

  test "flagging rules that are shadowed by earlier rules" do
    live =
      start_pruner_live!(
        rules: [
          [name: "broad", max_age: {1, :day}],
          [name: "media", queue: "media", max_len: 500]
        ]
      )

    refresh(live)

    assert has_element?(live, "#pruner-shadowed-media")
    refute has_element?(live, "#pruner-shadowed-broad")
  end

  test "showing rules as stored when no pruner is configured" do
    assert {:ok, _rule} = Pruner.insert(name: "media", queue: "media", max_len: 500)

    {:ok, live, _html} = live(build_conn(), "/oban/pruners")

    refresh(live)

    media = live |> element("#pruner-media") |> render()

    assert media =~ ~s(rel="is-stored")
    refute media =~ ~s(rel="is-active")
  end

  test "describing rules that match every job" do
    live = start_pruner_live!(rules: [[name: "default", max_age: :infinity]])

    refresh(live)

    default = live |> element("#pruner-default") |> render()

    assert default =~ "all jobs"
    assert default =~ "Forever"
  end

  test "warning when no pruner is configured" do
    assert {:ok, _rule} = Pruner.insert(name: "media", queue: "media", max_len: 500)

    {:ok, live, _html} = live(build_conn(), "/oban/pruners")

    refresh(live)

    assert live |> element("#warning-unconfigured") |> render() =~ "never applied"
    assert live |> element("#warning-no-default") |> render() =~ "retained forever"

    assert live |> element("#pruner-media") |> render() =~ ~s(rel="is-stored")
  end

  test "warning when configuration deletes rules on restart" do
    live = start_pruner_live!(sync_mode: :automatic, rules: [[name: "default", max_len: 1_000]])

    refresh(live)

    assert live |> element("#warning-automatic") |> render() =~ "deleted when the pruner restarts"
  end

  test "staying quiet when rules are applied as stored" do
    live = start_pruner_live!(rules: [[name: "default", max_len: 1_000]])

    refresh(live)

    refute live |> element("#warning-unconfigured") |> has_element?()
    refute live |> element("#warning-automatic") |> has_element?()
    refute live |> element("#warning-no-default") |> has_element?()
  end

  test "moving a rule within the evaluation chain" do
    live =
      start_pruner_live!(
        rules: [
          [name: "media", queue: "media", max_len: 500],
          [name: "audit", worker: "MyApp.Audit", max_age: {90, :days}],
          [name: "default", max_age: {1, :day}]
        ]
      )

    refresh(live)

    live |> element("#pruner-move-down-media") |> render_click()

    table = live |> element("#pruners-table") |> render()

    assert row_at(table, "audit") < row_at(table, "media")

    live |> element("#pruner-move-up-media") |> render_click()

    table = live |> element("#pruners-table") |> render()

    assert row_at(table, "media") < row_at(table, "audit")
  end

  test "pinning the default rule last, without reorder controls" do
    live =
      start_pruner_live!(
        rules: [
          [name: "media", queue: "media", max_len: 500],
          [name: "audit", worker: "MyApp.Audit", max_age: {90, :days}],
          [name: "default", max_age: {1, :day}]
        ]
      )

    refresh(live)

    refute live |> element("#pruner-move-up-default") |> has_element?()
    refute live |> element("#pruner-move-down-default") |> has_element?()

    assert live |> element("#pruner-move-up-media") |> render() =~ "disabled"
    assert live |> element("#pruner-move-down-audit") |> render() =~ "disabled"
    refute live |> element("#pruner-move-down-media") |> render() =~ "disabled"
  end

  describe "filtering" do
    test "filtering rules through the autocomplete toolbar" do
      live = start_pruner_live!(rules: standard_rules())

      refresh(live)

      live
      |> form("#search")
      |> tap(&render_change(&1, %{terms: "queues:media"}))
      |> tap(&render_submit(&1, %{}))

      assert_patch(live, pruners_path(queues: "media"))

      assert has_element?(live, "#pruner-media")
      refute has_element?(live, "#pruner-audit")
      refute has_element?(live, "#pruner-default")
    end

    test "filtering rules by name, match, mode, and status" do
      live = start_pruner_live!(rules: standard_rules())

      assert ~w(audit) = listed(live, workers: "MyApp.Audit")
      assert ~w(failures) = listed(live, states: "discarded")
      assert ~w(media) = listed(live, modes: "length")
      assert ~w(failures) = listed(live, stats: "paused")
      assert ~w(media audit) = listed(live, names: "media,audit")

      assert [] = listed(live, queues: "missing")
      assert live |> element("#pruners-no-matches") |> render() =~ "No matching rules"
    end

    test "clearing filters from the toolbar" do
      live = start_pruner_live!([rules: standard_rules()], queues: "media")

      refresh(live)

      live
      |> element("#search-reset")
      |> render_click()

      assert_patch(live, "/oban/pruners")
    end
  end

  describe "sorting" do
    test "sorting rules by different properties" do
      live = start_pruner_live!(rules: standard_rules())

      refresh(live)

      for mode <- ~w(name retention limit updated) do
        live |> element("a#sort-#{mode}") |> render_click()

        assert_patch(live, pruners_path(sort_by: mode, sort_dir: "asc"))
      end

      assert ~w(audit default failures media) = listed(live, sort_by: "name")
    end

    test "retaining filters while sorting" do
      live = start_pruner_live!([rules: standard_rules()], modes: "age")

      refresh(live)

      live |> element("a#sort-name") |> render_click()

      assert_patch(live, pruners_path(modes: "age", sort_by: "name", sort_dir: "asc"))
    end
  end

  describe "reordering" do
    test "disabling reorder controls while filtered or sorted" do
      live = start_pruner_live!([rules: standard_rules()], modes: "age")

      refresh(live)

      assert live |> element("#pruner-move-down-audit") |> render() =~ "disabled"

      assert live |> element("#pruner-move-down-audit") |> render() =~
               "Clear filters and sort by order"

      render_patch(live, pruners_path(sort_by: "name"))

      assert live |> element("#pruner-move-up-media") |> render() =~ "disabled"
    end
  end

  test "opening a rule from the table" do
    live = start_pruner_live!(rules: [[name: "media", queue: "media", max_len: 500]])

    refresh(live)

    live
    |> element("#pruner-media a")
    |> render_click()

    assert_patch(live, "/oban/pruners/media")

    assert render(live) =~ "Evaluation"
  end

  describe "read only access" do
    test "disabling the controls that change rules" do
      start_pruner!(rules: standard_rules())

      {:ok, live, _html} = live(build_conn(), "/oban-readonly/pruners")

      send(live.pid, :refresh)

      assert has_element?(live, "#new-pruner-button[aria-disabled]")
      assert live |> element("#pruner-move-down-media") |> render() =~ "disabled"
    end

    test "redirecting away from the new rule form" do
      start_pruner!(rules: standard_rules())

      assert {:error, {:live_redirect, %{to: "/oban-readonly/pruners"}}} =
               live(build_conn(), "/oban-readonly/pruners/new")
    end
  end

  test "navigating to pruners from other pages" do
    {:ok, live, _html} = live(build_conn(), "/oban/jobs")

    assert live |> element("#nav-pruners") |> has_element?()

    live
    |> element("#nav-pruners")
    |> render_click()

    assert_patch(live, "/oban/pruners")
  end

  test "redirecting unknown rule paths back to the index" do
    assert {:error, {:live_redirect, %{to: "/oban/pruners"}}} =
             live(build_conn(), "/oban/pruners/missing")
  end

  defp start_pruner!(opts) do
    stop_supervised!(Oban)

    name = start_supervised_oban!(engine: Oban.Pro.Engine, plugins: [{Pruner, opts}])

    name
    |> Oban.Registry.whereis({:plugin, Pruner})
    |> :sys.get_state()

    :ok
  end

  defp start_pruner_live!(opts, params \\ []) do
    start_pruner!(opts)

    {:ok, live, _html} = live(build_conn(), pruners_path(params))

    live
  end

  defp standard_rules do
    [
      [name: "media", queue: "media", max_len: 500],
      [name: "audit", worker: "MyApp.Audit", max_age: :infinity],
      [name: "failures", state: :discarded, max_age: {10, :minutes}, paused: true],
      [name: "default", max_age: {1, :day}]
    ]
  end

  defp listed(live, params) do
    html = render_patch(live, pruners_path(params))

    ~r/<li [^>]*id="pruner-([^"]+)"/
    |> Regex.scan(html)
    |> Enum.map(fn [_full, name] -> name end)
  end

  defp pruners_path([]), do: "/oban/pruners"
  defp pruners_path(params), do: "/oban/pruners?#{URI.encode_query(params)}"

  defp row_at(html, name) do
    {index, _length} = :binary.match(html, ~s(id="pruner-#{name}"))

    index
  end

  defp refresh(live) do
    send(live.pid, :refresh)

    render(live)
  end
end
