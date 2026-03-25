# Changelog for Oban Web v2.12

This is a major release that overhauls job details, the queues table, queue details, introduces a
crons page, adds a workflows page, and adds a job creation sidebar.

> #### Requirements {: .info}
>
> This release requires Oban v2.21+ and the new V14 migration due to important schema changes. For
> Pro users, v1.7+ is also required along with the v1.7.0 migration.

## 🔀 Workflows Page

There is a new page for viewing, filtering, and generally managing workflows. The table displays
workflow progress, activity counts, duration, and nested sub-workflows. Workflows can be filtered
by properties like name, workers, or status.

<video autoplay loop muted playsinline loading="lazy" preload="none" style="width: 100%; border-radius: 12px;">
  <source src="https://media.oban.pro/web-2-12-workflows-av1.mp4" type="video/mp4">
</video>

Clicking into a workflow brings you to a detail view with an interactive graph showing jobs as
stateful nodes with dependencies. The graph supports panning, zooming, directional layout
toggling, and a default tracking mode that follows executing nodes. Sub-workflow nodes can be
expanded inline to reveal their internal jobs, or navigated to for direct management such as
retrying or cancelling.

Workflow viewing remains fast on busy systems or with _large_ workflows thanks to the new
`oban_workflows` aggregate table in Pro v1.7. It's also compatible with Python Pro, though
cancel/retry actions require Elixir.

## ⏰ Crons Page

There's also a new page for viewing and managing cron entries. The table displays all static and
dynamic entries with history sparklines and activity details.

<video autoplay loop muted playsinline loading="lazy" preload="none" style="width: 100%; border-radius: 12px;">
  <source src="https://media.oban.pro/web-2-12-crons-av1.mp4" type="video/mp4">
</video>

The cron detail view includes natural language expressions like "Daily at 8:00 and 9:00" or
"Weekdays except Monday", along with cron entry specifics, and recent job history.

For Pro users, `DynamicCron` entires can be created, edited, paused, resumed, or deleted directly
from a form on the details page.

## 🔍 Job Details

The job detail page is rebuilt with a full-width layout and a new timeline component that shows
the job state machine as a branching diagram rather than a linear progression.

<video autoplay loop muted playsinline loading="lazy" preload="none" style="width: 100%; border-radius: 12px;">
  <source src="https://media.oban.pro/web-2-12-jobs-details-av1.mp4" type="video/mp4">
</video>

A scoped chart displays execution history for that worker's previous jobs and jobs in an
incomplete, non-executing state can now be edited directly.

Executing Pro jobs display live diagnostics including process status, reductions, memory, and
current stacktrace. The diagnostics panel persists after job completion with a "Stale" indicator
showing the data is from when the job was running.

## ➡️ Queues Table and Details

The queues table is redesigned with a utilization gauge and a history sparkline showing 5-minute
throughput for each queue. The queue sidebar provided minimal value, and it was removed to make
room for the additional data displayed per-row.

<video autoplay loop muted playsinline loading="lazy" preload="none" style="width: 100%; border-radius: 12px;">
  <source src="https://media.oban.pro/web-2-12-queues-av1.mp4" type="video/mp4">
</video>

The queue detail page adds status badges for paused, partial, and terminating states, with
pause/resume, stop, and edit buttons in the header. Partitioning controls are expanded with meta
options and burst mode configuration.

## v2.12.0 - 2026-03-23

While all bug fixes are listed below, the enhancements section only covers a portion of the new
features. For enhancements, a video is worth many thousands of words.

### Enhancements

- [Dashboard] Preserve refresh changes between page changes

  The refresh reverted to the original value between changes because there wasn't a new liveview
  connection. Now the stored refresh value is synced on change, and reloaded when the component
  mounts.

- [Dahboard] Add a 30s option for refreshing

  It's a simple addition that makes watching the cron page a bit more sensible.

- [Dashboard] Serve dynamically loaded mask based svg icons

  Rather than manually defining SVG icons inline, SVG files are tracked and dynamically loaded
  from a compiled assets module.

- [Dashboard] Serve font as static asset instead of embedding

  Extract font out of the `app.css` and serve it as a stand-alone asset for better caching.

- [Dashboard] Add help button to primary toolbar

  The keyboard shortcuts modal was only accessible via the ? key with no visual indication it
  existed. Added a help dropdown to the toolbar that links to documentation and opens the
  shortcuts modal.

- [Jobs] Support suspended state in sidebar and details

  The latest Oban version adds a proper `suspended` state, so there's no more on_hold
  psuedo-state.

- [Jobs] Jobs rescued by any lifeline are detectable

  Change the language for orphans to correctly indicate that any lifeline may have rescued them.

- [Jobs] Redesign timeline as state machine visualization

  Replace the linear horizontal timeline with a branching layout that accurately represents the
  job state machine. Entry states (scheduled/retryable) flow into available, then executing, which
  branches to terminal states (completed/cancelled/discarded).

- [Jobs] Add diagnostics for executing jobs

  Actively executing `Oban.Pro.Worker` jobs now display diagnostics including process status,
  reductions, memory, and the current stacktrace.

- [Jobs] Add job editing to job detail page

  Job's in an incomplete and non-executing state can have their attributes edited. Internally,
  `Oban.update_job/3` is used to perform the update, so standard validations still apply.

- [Jobs] Refine layout and error display for job details

  Restructure information for job details to emphasize what's important (args, the most recent
  error), while providing control over which information is displayed.

- [Jobs] Show history chart component for job detail

  The new component uses exact historic information for the current job rather than the aggregate
  metrics used for the primary job chart.

- [Jobs] Add "New Job" drawer for creating jobs

  Jobs can now be created directly from the Jobs page using a slide-out drawer. The form includes
  fields for worker, args, queue, priority, max attempts, scheduled time, and tags. After
  creation, the user is navigated to the new job's detail page.

- [Crons] Use name provided by crontab for entry job history

  The `cron_name` calculated for Elixir entries isn't compatible with those generated by Python.
  The `oban-py` metrics now include a `name` option that is used to correctly match entries up
  with historic jobs.

- [Crons] Add cron parser for complex expressions

  Parse cron fields into structured data before describing them, enabling support for:

  - Combined DOM/DOW patterns like "The 1st, only on Mondays"
  - Complement detection, "Daily except the 1st" or "except Tuesdays"
  - Multiple hour values, "Daily at 8:00, 9:00, and 10:00"
  - Weekday/weekend recognition

  It's also switched to a 24-hour time format for international consistency.

- [Queues] Remove sidebar from queues page                                                                                                                                       The sidebar filters (paused, terminating, modes, nodes) added little

  The sidebar filters (paused, terminating, modes, nodes) added little value for a typically small
  dataset while consuming significant screen space. Filtering remains available via the search
  component.

- [Queues] Add history sparkline graph to queues table

  Display a 5-minute throughput history for each queue using a sparkline
  visualization with 5-second rollups (60 data points). Hovering over bars
  shows the job count and timestamp for that interval.

- [Queues] Refine queue detail forms and layout

  Expand the queue form partitioning controls with "meta" options and burst mode. Also changes to
  standard form inputs for numbers and select boxes within the edit form to simplify event
  handling.

- [Queues] Redesign queue details with actions and history

  Add status badges for paused, partial, and terminating states. Include pause/resume, stop, and
  edit buttons in the header for quick access. Display queue execution history in a chart
  alongside stats.

- [Pages] Add empty states for workflows, crons, and queues

  Each page now shows a helpful message with an icon and documentation link when there's nothing
  to display. The queues page distinguishes between having no queues configured versus filters
  hiding all results.

- [Pages] Improve dark mode color consistency and contrast

  Standardize border colors across form inputs and controls, align form input backgrounds, and
  increase contrast for disabled elements.

### Bug Fixes

- [Dahboard] Fix instance switching when resolver returns a list

  Ensure the instance name and allowed instances are strings before comparison

- [Dashboard] Poll registry instead of blocking on telemetry

  Replace telemetry-based init that could block for 15 seconds waiting for an init event that may
  have already fired. Now polls the Oban registry, avoiding the race condition that caused slow
  websocket reconnections.

- [Dashboard] Cache sidebar counts to prevent flickering

  When the metric reporter's `check_interval` exceeds the 2s lookback window, counts briefly show
  as zero between broadcasts. Cache previous non-empty counts in a centralized Metrics module and
  return them when `Met.latest/3` returns an empty map.

- [Dashboard] Automatically update theme when OS theme changes

  Listen for prefers-color-scheme media query changes so the theme updates in real-time when the
  browser or OS switches between light and dark mode.

- [Standalone] Use the Postgres notifier for standalone instance

  The PG notifier can't (easily) connect to an external cluster for notifications. Connection is
  possible through the Postgres notifier.

