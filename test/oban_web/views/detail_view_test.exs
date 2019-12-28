defmodule ObanWeb.DetailViewTest do
  use ExUnit.Case, async: true

  alias Oban.Job
  alias ObanWeb.DetailView

  describe "iso8601_to_words/2" do
    test "converting an iso8601 string into time in words" do
      words =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(-1)
        |> NaiveDateTime.to_iso8601()
        |> DetailView.iso8601_to_words()

      assert words =~ "1s ago"
    end
  end

  describe "attempted_by/1" do
    test "extracting the node that attempted a job" do
      job = %Job{attempted_by: nil}

      assert DetailView.attempted_by(job) == "Not Attempted"
      assert DetailView.attempted_by(%{job | attempted_by: []}) == "Not Attempted"
      assert DetailView.attempted_by(%{job | attempted_by: ["node", "q", "1"]}) == "node"
    end
  end

  describe "timeline_state/2" do
    import DetailView, only: [timeline_state: 2]

    test "determining the state class" do
      at = NaiveDateTime.utc_now()

      # Executing
      assert timeline_state("executing", %Job{state: "executing"}) =~ "--started"
      assert timeline_state("executing", %Job{state: "completed", attempted_at: at}) =~ "--finished"

      # Completed
      assert timeline_state("completed", %Job{state: "completed"}) =~ "--started"
      assert timeline_state("completed", %Job{state: "completed", completed_at: at}) =~ "--finished"

      # Discarded
      refute timeline_state("discarded", %Job{state: "completed"})
      assert timeline_state("discarded", %Job{state: "discarded"}) =~ "--finished"
    end

    test "determining the state when the job is retryable" do
      at = NaiveDateTime.utc_now()

      assert timeline_state("inserted", %Job{state: "retryable", inserted_at: at}) =~ "--finished"
      assert timeline_state("scheduled", %Job{state: "retryable", scheduled_at: at}) =~ "--retrying"
      refute timeline_state("executing", %Job{state: "retryable"})
      refute timeline_state("completed", %Job{state: "retryable"})
      refute timeline_state("discarded", %Job{state: "retryable"})
    end
  end

  describe "timeline_time/2" do
    import DetailView, only: [timeline_time: 2]

    test "formatting relative timestamps for a completed job" do
      now = NaiveDateTime.utc_now()
      job = %Job{attempted_at: now, completed_at: now}

      assert timeline_time("completed", job) == "—"
      assert timeline_time("completed", Map.put(job, :relative_completed_at, -1)) == "1s ago (00:00)"
    end
  end
end
