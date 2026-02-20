defmodule Oban.Web.Jobs.TimelineComponentTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  alias Oban.Web.Jobs.TimelineComponent

  @now ~U[2024-01-15 12:00:00Z]
  @os_time DateTime.to_unix(@now)

  describe "render/1" do
    test "renders all seven state boxes" do
      job = build_job(state: "scheduled")
      html = render_timeline(job)

      assert html =~ "timeline-scheduled"
      assert html =~ "timeline-retryable"
      assert html =~ "timeline-available"
      assert html =~ "timeline-executing"
      assert html =~ "timeline-completed"
      assert html =~ "timeline-cancelled"
      assert html =~ "timeline-discarded"
    end

    test "includes data attributes for connector drawing" do
      job = build_job(state: "executing", attempted_at: @now)
      html = render_timeline(job)

      assert html =~ ~s(data-entry-scheduled="true")
      assert html =~ ~s(data-engaged="true")
    end
  end

  describe "scheduled job (first attempt)" do
    test "scheduled box is active (blue)" do
      job = build_job(state: "scheduled")
      html = render_timeline(job)

      assert has_active_box?(html, "scheduled")
      assert has_inactive_box?(html, "available")
      assert has_inactive_box?(html, "executing")
      assert has_inactive_box?(html, "completed")
    end

    test "shows timestamp on scheduled box" do
      scheduled_at = DateTime.add(@now, -60, :second)
      job = build_job(state: "scheduled", scheduled_at: scheduled_at)
      html = render_timeline(job)

      assert html =~ "1m ago"
    end

    test "retryable box is inactive" do
      job = build_job(state: "scheduled")
      html = render_timeline(job)

      assert has_inactive_box?(html, "retryable")
    end
  end

  describe "executing job (first attempt)" do
    test "executing box is active, prior states are completed" do
      attempted_at = DateTime.add(@now, -30, :second)

      job =
        build_job(
          state: "executing",
          attempt: 1,
          scheduled_at: DateTime.add(@now, -60, :second),
          attempted_at: attempted_at
        )

      html = render_timeline(job)

      assert has_completed_box?(html, "scheduled")
      assert has_completed_box?(html, "available")
      assert has_active_box?(html, "executing")
      assert has_inactive_box?(html, "completed")
    end

    test "shows duration on executing box" do
      attempted_at = DateTime.add(@now, -30, :second)

      job = build_job(state: "executing", attempted_at: attempted_at)

      assert render_timeline(job) =~ "00:30"
    end
  end

  describe "completed job" do
    test "all states in path show as completed (green)" do
      job =
        build_job(
          state: "completed",
          attempt: 1,
          scheduled_at: DateTime.add(@now, -120, :second),
          attempted_at: DateTime.add(@now, -60, :second),
          completed_at: DateTime.add(@now, -30, :second)
        )

      html = render_timeline(job)

      assert has_completed_box?(html, "scheduled")
      assert has_completed_box?(html, "available")
      assert has_completed_box?(html, "executing")
      assert has_completed_box?(html, "completed")
      assert has_inactive_box?(html, "cancelled")
      assert has_inactive_box?(html, "discarded")
    end

    test "shows relative time on executing box for completed job" do
      attempted_at = DateTime.add(@now, -60, :second)
      completed_at = DateTime.add(@now, -30, :second)

      job = build_job(state: "completed", attempted_at: attempted_at, completed_at: completed_at)

      assert render_timeline(job) =~ "1m ago"
    end
  end

  describe "cancelled job" do
    test "cancelled box shows negative status (rose)" do
      job =
        build_job(
          state: "cancelled",
          attempted_at: DateTime.add(@now, -60, :second),
          cancelled_at: DateTime.add(@now, -30, :second)
        )

      html = render_timeline(job)

      assert has_negative_box?(html, "cancelled")
      assert has_inactive_box?(html, "completed")
      assert has_inactive_box?(html, "discarded")
    end
  end

  describe "discarded job" do
    test "discarded box shows negative status (rose)" do
      job =
        build_job(
          state: "discarded",
          attempted_at: DateTime.add(@now, -60, :second),
          discarded_at: DateTime.add(@now, -30, :second)
        )

      html = render_timeline(job)

      assert has_negative_box?(html, "discarded")
      assert has_inactive_box?(html, "completed")
      assert has_inactive_box?(html, "cancelled")
    end
  end

  describe "retryable job" do
    test "retryable box is active, scheduled is inactive" do
      job =
        build_job(
          state: "retryable",
          attempt: 1,
          scheduled_at: DateTime.add(@now, 60, :second)
        )

      html = render_timeline(job)

      assert has_active_box?(html, "retryable")
      assert has_inactive_box?(html, "scheduled")
      assert has_inactive_box?(html, "available")
      assert has_inactive_box?(html, "executing")
    end

    test "shows timestamp on retryable box" do
      scheduled_at = DateTime.add(@now, 60, :second)

      job =
        build_job(
          state: "retryable",
          scheduled_at: scheduled_at
        )

      html = render_timeline(job)

      assert html =~ "in 1m"
    end

    test "scheduled box has no timestamp when retryable is active" do
      job =
        build_job(
          state: "retryable",
          scheduled_at: DateTime.add(@now, 60, :second)
        )

      html = render_timeline(job)

      # The scheduled box should show em-dash, not a time
      scheduled_section = extract_box(html, "scheduled")
      refute scheduled_section =~ "ago"
      refute scheduled_section =~ "in "
    end

    test "available box has no timestamp when retryable" do
      job =
        build_job(
          state: "retryable",
          attempted_at: DateTime.add(@now, -60, :second),
          scheduled_at: DateTime.add(@now, 60, :second)
        )

      html = render_timeline(job)

      available_section = extract_box(html, "available")
      refute available_section =~ "ago"
    end
  end

  describe "retry attempt (attempt > 1)" do
    test "uses retryable entry path when attempt > 1" do
      job =
        build_job(
          state: "executing",
          attempt: 2,
          scheduled_at: DateTime.add(@now, -30, :second),
          attempted_at: DateTime.add(@now, -10, :second)
        )

      html = render_timeline(job)

      # Retryable should be completed (green), scheduled should be inactive
      assert has_completed_box?(html, "retryable")
      assert has_inactive_box?(html, "scheduled")
      assert has_completed_box?(html, "available")
      assert has_active_box?(html, "executing")
    end

    test "scheduled box has no timestamp on retry attempts" do
      job =
        build_job(
          state: "executing",
          attempt: 2,
          scheduled_at: DateTime.add(@now, -30, :second),
          attempted_at: DateTime.add(@now, -10, :second)
        )

      html = render_timeline(job)

      scheduled_section = extract_box(html, "scheduled")
      refute scheduled_section =~ "ago"
    end

    test "retryable box shows timestamp on retry attempts" do
      scheduled_at = DateTime.add(@now, -30, :second)

      job =
        build_job(
          state: "executing",
          attempt: 2,
          scheduled_at: scheduled_at,
          attempted_at: DateTime.add(@now, -10, :second)
        )

      html = render_timeline(job)

      retryable_section = extract_box(html, "retryable")
      assert retryable_section =~ "30s ago"
    end
  end

  describe "data attributes for path" do
    test "entry is scheduled for first attempt" do
      job = build_job(state: "scheduled", attempt: 1)
      html = render_timeline(job)

      assert html =~ ~s(data-entry-scheduled="true")
      assert html =~ ~s(data-entry-retryable="false")
    end

    test "entry is retryable for retry attempts" do
      job = build_job(state: "executing", attempt: 2, attempted_at: @now)
      html = render_timeline(job)

      assert html =~ ~s(data-entry-scheduled="false")
      assert html =~ ~s(data-entry-retryable="true")
    end

    test "engaged-available is true when attempted" do
      job = build_job(state: "executing", attempted_at: @now)
      html = render_timeline(job)

      assert html =~ ~s(data-engaged="true")
    end

    test "engaged-available is false when not attempted" do
      job = build_job(state: "scheduled")
      html = render_timeline(job)

      assert html =~ ~s(data-engaged="false")
    end

    test "terminal-completed is set for completed jobs" do
      job = build_job(state: "completed", completed_at: @now, attempted_at: @now)
      html = render_timeline(job)

      assert html =~ ~s(data-terminal-completed="true")
      assert html =~ ~s(data-terminal-cancelled="false")
      assert html =~ ~s(data-terminal-discarded="false")
    end
  end

  # Helper functions

  defp render_timeline(job) do
    render_component(&TimelineComponent.render/1, job: job, os_time: @os_time)
  end

  defp build_job(attrs) do
    defaults = %{
      id: 1,
      state: "available",
      queue: "default",
      worker: "MyApp.Worker",
      args: %{},
      meta: %{},
      tags: [],
      errors: [],
      attempt: 1,
      max_attempts: 20,
      attempted_at: nil,
      cancelled_at: nil,
      completed_at: nil,
      discarded_at: nil,
      inserted_at: @now,
      scheduled_at: @now
    }

    struct!(Oban.Job, Map.merge(defaults, Map.new(attrs)))
  end

  defp extract_box(html, state) do
    html
    |> Floki.parse_fragment!()
    |> Floki.find("#timeline-#{state}")
    |> Floki.raw_html()
  end

  defp has_active_box?(html, state) do
    box = extract_box(html, state)
    box =~ "border-blue-400"
  end

  defp has_completed_box?(html, state) do
    box = extract_box(html, state)
    box =~ "border-emerald-400"
  end

  defp has_inactive_box?(html, state) do
    box = extract_box(html, state)
    box =~ "border-gray-300"
  end

  defp has_negative_box?(html, state) do
    box = extract_box(html, state)
    box =~ "border-rose-400"
  end
end
