defmodule Oban.Web.Live.RebootingTest do
  use Oban.Web.Case

  import Phoenix.LiveViewTest

  test "waiting for oban config while mounting during a restart" do
    task =
      Task.async(fn ->
        Process.sleep(25)

        {:ok, _} = Oban.start_link(repo: Repo, peer: Oban.Peers.Global, notifier: Oban.Notifiers.PG)
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
end
