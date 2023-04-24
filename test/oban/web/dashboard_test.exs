defmodule Oban.Web.DashboardTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

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
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #states #state-#{state}")
    |> render_click()

    render(live)
  end
end
