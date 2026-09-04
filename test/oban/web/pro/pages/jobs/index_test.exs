if Code.ensure_loaded?(Oban.Pro) do
  defmodule Oban.Web.Pro.Pages.Jobs.IndexTest do
    use Oban.Web.ProCase

    setup do
      start_supervised_oban!(queues: [chunks: 1], stage_interval: 10)

      {:ok, live, _html} = live(build_conn(), "/oban")

      {:ok, live: live}
    end

    test "folding executing chunk siblings into their leader", %{live: live} do
      {worker_pid, [leader, sibling, _sibling]} =
        start_blocked_chunk!([%{ref: 1}, %{ref: 2}, %{ref: 3}])

      # The blocked leader fills the queue, so this chunk is only picked up by the inline drain
      [finished_leader, finished] = run_chunk!([%{ref: 4}, %{ref: 5}])

      click_state(live, "executing")

      assert has_element?(live, "#job-#{leader.id}")
      assert has_element?(live, "#job-chunk-#{leader.id}", "3")
      refute has_element?(live, "#job-#{sibling.id}")

      click_state(live, "completed")

      assert has_element?(live, "#job-#{finished.id}")

      assert has_element?(
               live,
               "#job-chunk-#{finished.id}[data-title='In a chunk led by job #{finished_leader.id}']"
             )

      finish_chunk(worker_pid)
    end

    defp click_state(live, state) do
      live
      |> element("#sidebar #states #filter-#{state}")
      |> render_click()
    end
  end
end
