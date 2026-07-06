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
  <source src="https://media.oban.pro/web-2-12-workflows-av1.mp4" type="video/mp4" codecs="av01">
  <source src="https://media.oban.pro/web-2-12-workflows.mp4" type="video/mp4">
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
  <source src="https://media.oban.pro/web-2-12-crons-av1.mp4" type="video/mp4" codecs="av01">
  <source src="https://media.oban.pro/web-2-12-crons.mp4" type="video/mp4">
</video>

The cron detail view includes natural language expressions like "Daily at 8:00 and 9:00" or
"Weekdays except Monday", along with cron entry specifics, and recent job history.

For Pro users, `DynamicCron` entires can be created, edited, paused, resumed, or deleted directly
from a form on the details page.

## 🔍 Job Details

The job detail page is rebuilt with a full-width layout and a new timeline component that shows
the job state machine as a branching diagram rather than a linear progression.

<video autoplay loop muted playsinline loading="lazy" preload="none" style="width: 100%; border-radius: 12px;">
  <source src="https://media.oban.pro/web-2-12-jobs-details-av1.mp4" type="video/mp4" codecs="av01">
  <source src="https://media.oban.pro/web-2-12-jobs-details.mp4" type="video/mp4">
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
  <source src="https://media.oban.pro/web-2-12-queues-av1.mp4" type="video/mp4" codecs="av01">
  <source src="https://media.oban.pro/web-2-12-queues.mp4" type="video/mp4">
</video>

The queue detail page adds status badges for paused, partial, and terminating states, with
pause/resume, stop, and edit buttons in the header. Partitioning controls are expanded with meta
options and burst mode configuration.

## v2.12.6 - 2026-07-06

### Enhancements

- [Jobs] Build jobs through worker `new/2` when available

  The new job drawer always built changesets with `Job.new/2`, bypassing worker-level defaults,
  validation, and Pro stages (recorded, chain, etc). Now we resolve the worker module and use its
  `new/2` when it's loaded on the Web instance, falling back to `Job.new/2` when the module isn't
  available.

### Bug Fixes

- [Dashboard] Resolve Elixir 1.20 compilation warnings

  Fix all of the warnings surfaced by the Elixir v1.20 type checker and upgrade any packages with
  errors or secutity warnings.

- [Job Details] Fix clearing tags when editing jobs

  Treat blank tag input as an empty list when editing jobs, while leaving it as `nil` during job
  creation.

- [Job Details] Add clipboard fallback for insecure contexts

  The navigator.clipboard API is only available in secure contexts (HTTPS or localhost), so
  copying job args, meta, and stacktraces failed with "navigator.clipboard is undefined" when Oban
  Web was served over plain HTTP. Fall back to execCommand so copy actions work in those
  environments.

- [Job Details] Fix new job form ignoring the scheduled at time

  `DateTime.from_iso8601/1` returns a three-element tuple, but we only matched on `{:ok,
  datetime}`. That clause never matched, so parsing always returned `nil` and jobs created with a
  scheduled time ran immediately instead. Match the full tuple so the selected time is applied.

- [Job Details]  Stack timeline labels on narrow screens

  State boxes in the job timeline placed the state label and timestamp in a row that was too
  narrow until the xl breakpoint, causing the timestamp to wrap awkwardly and the content to
  bleed. Now the label and timestamp are stacked below xl, switching to side-by-side where there's
  room to fit them.

- [Cron] Fix cron and tag history queries for CockroachDB

  The cron history and tag suggestion queries relied on the Postgres-only implicit `value` column
  name. CRDB names it after the function instead, which caused an `undefined_column` error.

  Now the set-returning function is wrapped in a derived table with an explicit column alias for
  all engines.

## v2.12.5 - 2026-05-26

### Enhancements

- [Jobs] Display awaitable signals in the job details page

  Add a section that decodes and displays signal payloads sent via
  `Oban.Pro.Worker.signal/2`. While a job is parked waiting, the section
  shows "Awaiting Signal" with the deadline. Once a signal arrives, it
  switches to "Received Signal".

- [Resolver] Add `format_signal/2` resolver callback

  This allows customizing the decoded output,mirroring what's available
  with `format_recorded/2`.

### Bug Fixes

- [Jobs] Restrict unauthorized job editing and updates with new permission

  The save-job event handler previously dispatched changes from any client
  without checking access controls, allowing a read-only user to rewrite a
  job's worker module and potentially trigger code execution on the next
  attempt. Editing now requires `:update_jobs` permission, which is
  enabled by default for `:all` and disabled for `:read_only`.

- [Cron] Prevent malicious cron expressions from unrestricted memory allocation

  A maliciously crafted cron expression like "0 0 1--100000000 \* \*" could
  trigger multi-gigabyte allocations when `describe/1` eagerly expanded
  the range during formatting. Range, value, and step parsing now validate
  against per-field bounds and require ranges to be non-decreasing, so
  out-of-domain inputs are rejected before any expansion occurs.

## v2.12.4 - 2026-05-11

### Changes

- [Dashboard] Upgrade oban_pro dependency to full v1.7 release

  Require the full v1.7 release rather than a release candidate.

### Bug Fixes

- [Dashboard] Escape names with reserved URL characters in paths

  Safely handle queues or crons with names like `foo/bar.baz` when linking from the queues and
  crons tables.

- [Workflow] Fix workflow queries ignoring custom prefix

  Two raw SQL fragments in WorkflowQuery referenced tables without a schema qualifier, causing a
  mismatch with the configured Oban prefix. Both fragments now inject the prefix as a quoted
  identifier so they honor the configured prefix like any other Oban.Repo queries.

- [Cron] Fix crash on cron page when an entry uses @reboot

  The `next_at/2` function returns `:unknown` for `@reboot` crons, which fell through to
  `maybe_to_unix/1` and crashed. Guard the helper on a `DateTime` struct and return an empty
  string for anything else, safely convering `nil` or `:unknown`.

- [Cron] Fix crash loading cron history on SQLite

  The `COALESCE` fragment used to compute the `finished_at` time was untyped, so Ecto couldn't
  apply the `:utc_datetime_usec` load callback. Postgrex would cast the value automatically, but
  exqlite returned a string and crashed downstream locations expecting a DateTime.

## v2.12.3 - 2026-04-15

### Bug Fixes

- [Dashboard] Switch icons from inline SVG to CSS masks

  CSP doesn't allow inline styles, which includes the url-masks that our app was using for icons.
  This removes the icons/asset pipeline in favor of the standard Tailwind plugin approach used by
  modern Phoenix apps

## v2.12.2 - 2026-03-31

### Enhancements

- [Jobs] Allow editing jobs in any state except `executing`

  `Oban.update_job/3` allows editing any non-executing job, so the detail component's edit form
  should as well.

- [Standalone] Ship inetrc in standalone Docker image for native DNS resolution (#173)

  The BEAM VM's built-in DNS resolver ignores `/etc/resolv.conf`, which prevents the standalone
  image from resolving internal hostnames on platforms like Fly.io and Kubernetes with CoreDNS.

### Bug Fixes

- [Query] Prevent table check with non-PostgreSQL engines

  The crons and workflows table checks only apply to Pro, and only Postgres engines should check
  whether the tables exist.

## v2.12.1 - 2026-03-25

### Bug Fixes

- [Dashboard] Include `priv/timezones.txt` in hex package

  The timezones file wasn't included in the package files list, which broke compilation for
  downloaded packages.

## v2.12.0 - 2026-03-25

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

- [Queues] Remove sidebar from queues page The sidebar filters (paused, terminating, modes, nodes) added little

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
