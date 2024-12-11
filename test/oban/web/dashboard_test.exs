defmodule Oban.Web.DashboardTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  test "forbidding mount using a resolver callback" do
    assert {:error, {:redirect, redirect}} = live(build_conn(), "/oban-limited")
    assert %{to: "/", flash: %{"error" => "Access forbidden"}} = redirect
  end

  test "waiting for oban config while mounting during a restart" do
    task =
      Task.async(fn ->
        Process.sleep(25)

        {:ok, _} =
          Oban.start_link(repo: Repo, peer: Oban.Peers.Global, notifier: Oban.Notifiers.PG)

        {:ok, _} = Oban.Met.start_link(conf: Oban.config())

        receive do
          :mounted -> :ok
        after
          1_000 -> :error
        end
      end)

    assert {:ok, _, _} = live(build_conn(), "/oban")

    send(task.pid, :mounted)

    assert :ok = Task.await(task)
  end

  describe "isolation" do
    test "viewing available jobs for a custom oban supervisor" do
      start_supervised_oban!(name: ObanPrivate, prefix: "private")

      {:ok, live, _html} = live(build_conn(), "/oban-private")

      job_1 = Job.new(%{}, worker: AlphaWorker)
      job_2 = Job.new(%{}, worker: DeltaWorker)
      job_3 = Job.new(%{}, worker: GammaWorker)

      Oban.insert_all(ObanPrivate, [job_1, job_2, job_3])

      html = click_state(live, "available")

      assert html =~ "AlphaWorker"
      assert html =~ "DeltaWorker"
      assert html =~ "GammaWorker"
    end

    test "routing to the configured path for a mount point" do
      start_supervised_oban!(name: ObanPrivate, prefix: "private")

      assert {:error, {:live_redirect, %{to: "/oban-private/queues"}}} =
               live(build_conn(), "/oban-private/queues/omicron")
    end

    test "switching between actively running instances" do
      start_supervised_oban!(name: Oban)
      start_supervised_oban!(name: ObanPrivate, prefix: "private")

      {:ok, live, _html} = live(build_conn(), "/oban")

      assert has_element?(live, "#instance-select li[phx-value-name=Oban]")
      assert has_element?(live, "#instance-select li[phx-value-name=ObanPrivate]")

      change_instance(live, "ObanPrivate")

      assert has_element?(live, "#instance-select-button", "ObanPrivate")
    end

    test "disallowing switching to unresolved instances" do
      start_supervised_oban!(name: Oban)
      start_supervised_oban!(name: ObanPrivate, prefix: "private")

      {:ok, live, _html} = live(build_conn(), "/oban-private")

      refute has_element?(live, "#instance-select li[phx-value-name=Oban]")
      assert has_element?(live, "#instance-select li[phx-value-name=ObanPrivate]")
    end

    test "defaulting to the first found running instance" do
      start_supervised_oban!(name: ObanPrivate, prefix: "private")

      {:ok, live, _html} = live(build_conn(), "/oban")

      refute has_element?(live, "#instance-select li[phx-value-name=Oban]")
      assert has_element?(live, "#instance-select li[phx-value-name=ObanPrivate]")
    end
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #states #state-#{state}")
    |> render_click()

    render(live)
  end

  defp change_instance(live, name) do
    live
    |> element("#instance-select li[role=option]", name)
    |> render_click()
  end
end
