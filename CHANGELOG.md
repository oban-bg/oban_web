# Changelog for Oban Web v2.13

This release adds a pruners page, archived job browsing, a reworked jobs chart and sidebar, and
sharpens every single page to optimize triage and overall accessibility.

> #### Requirements {: .info}
>
> This release requires Oban v2.24+. For Pro users, v1.8+ is required for the pruners page,
> archived jobs, compensations, and chunk views, along with the v1.8.0 migration.

## 🧹 Pruners Page

There is a new page for viewing and managing Pro pruning rules. In Pro v1.8 pruning rules live in
the database rather than static config, the dashboard shows persisted rules, and allows editing at
runtime.

<video autoplay loop muted playsinline loading="lazy" preload="none" style="width: 100%; border-radius: 12px;">
  <source src="https://oban-pro-assets.s3.eu-west-2.amazonaws.com/web-2-13-pruners-av1.mp4" type="video/mp4" codecs="av01">
  <source src="https://oban-pro-assets.s3.eu-west-2.amazonaws.com/web-2-13-pruners.mp4" type="video/mp4">
</video>

Rules are shown in order with their details, and the index supports all the usual filtering and
sorting. It's also possible to reorder rules to change precedence.

Retention, limits, and scoping can be edited on each Rule's detail page. New rules can also be
created on the fly for users with proper access.

## 🗄️ Archived Jobs

The new Pruner also brought automatic archiving for select rules, and archived jobs are visible in
`archive` mode. Archived jobs can be filtered, inspected, and deleted like live jobs, with any
functionality (like cancellation) that doesn't apply disabled.

<video autoplay loop muted playsinline loading="lazy" preload="none" style="width: 100%; border-radius: 12px;">
  <source src="https://oban-pro-assets.s3.eu-west-2.amazonaws.com/web-2-13-archive-av1.mp4" type="video/mp4" codecs="av01">
  <source src="https://oban-pro-assets.s3.eu-west-2.amazonaws.com/web-2-13-archive.mp4" type="video/mp4">
</video>

## 📊 Jobs Chart and Sidebar

The jobs chart is rebuilt for more intuitive metric comparisons. Filtering by state dims all other
values, and state/node/worker grouping follows filters automatically. The chart refreshes on every
tick now, scrolls smoothly, and avoids rescaling during activity spikes.

<video autoplay loop muted playsinline loading="lazy" preload="none" style="width: 100%; border-radius: 12px;">
  <source src="https://oban-pro-assets.s3.eu-west-2.amazonaws.com/web-2-13-jobs-chart-av1.mp4" type="video/mp4" codecs="av01">
  <source src="https://oban-pro-assets.s3.eu-west-2.amazonaws.com/web-2-13-jobs-chart.mp4" type="video/mp4">
</video>

The sidebar is now stateful and options are persistent. The queue's count follows the current
state, so filtering by `discarded` shows how many discarded jobs each queue holds, etc. Sections
remember whether they're collapsed, queue rows link to their detail page, and deep links like
select the right state on initial render.

## 🔗 Chunks, Chains, and Backfills

Chunks, chains, and backfills are easily identifiable, filterable, and fully navigable.

Executing chunks appear as a combined unit, with the leader row showing the total chunk size.
Siblings are still listed in other states, and they have a link back to the leader job.

<video autoplay loop muted playsinline loading="lazy" preload="none" style="width: 100%; border-radius: 12px;">
  <source src="https://oban-pro-assets.s3.eu-west-2.amazonaws.com/web-2-13-chains-av1.mp4" type="video/mp4" codecs="av01">
  <source src="https://oban-pro-assets.s3.eu-west-2.amazonaws.com/web-2-13-chains.mp4" type="video/mp4">
</video>

Chains and backfills show a badge on the jobs table, matching chunks. Job details gain Chain and
Backfill rows that link to the previous, next, and all related jobs in the sequence, along with
each job's execution state. All three composition tools gain a filter, like `chain:1234` to help
target all related jobs.

## v2.13.0 - 2026-09-15

### Enhancements

- [Crons] Sharpen the crons index for triage

  Next run is evaluated in the entry's own timezone, paused entries read "paused", and `@reboot`
  entries read "at reboot". Last and next run carry the exact clock in a tooltip, the schedule sort
  orders by frequency, and the name sort groups entries by handler. Dynamic and decorated entries
  are marked with icons in the status column, and job history is only fetched for the page that
  renders.

- [Crons] Show decorated crons by their handler

  Pro v1.8 persists decorated cron functions as `Oban.Pro.Decorator` entries. The crons page
  derives the handler name for those entries and uses it consistently.

- [Crons] Use inline editing for cron details

  Cron details edit in place, matching pruners. Clearing an option like queue, timezone, tags, or
  args removes it rather than being ignored, renaming reopens the cron at its new address, and
  invalid expressions or args are reported inline.

- [Dashboard] Make search, sort, and tables usable by keyboard

  Search is a proper combobox where `Tab` only completes when there's something to complete, arrow
  keys move through suggestions, and `Enter` picks one. Sort is a real menu with a separate
  direction toggle, and the header, nav, and footer are fully keyboard operable.

- [Dashboard] Show a second unit in relative times

  Relative times carry a second unit for hours and days, so "1h" reads as "1h 14m" and "1d" as
  "1d 9h", which is enough resolution to tell whether a cron is late.

- [Dashboard] Match detail pages for queues, crons, pruners, and jobs

  Detail pages share the same layout, form behavior, and language. Edit forms validate every field
  and only submit what changed, so a refresh never overwrites edits in progress. Unavailable
  actions explain why in their tooltips, deletes ask for confirmation, and copy buttons show
  "Copied" feedback.

- [Dashboard] Share empty state components across pages

  Empty, no-match, promo, and missing-migration states render through shared components. Every
  filtered miss offers a way to clear filters, and workflows prompt for the missing migration
  instead of claiming Pro is absent.

- [Dashboard] Align headings, footers, and history for index pages

  Index panels share one title style and one paging footer that's hidden until a page is full.
  Applying or clearing a search replaces history, so Back leaves the page instead of stepping
  through filters.

- [Dashboard] Improve contrast and screen reader labels throughout

  State icons, counts, sparklines, toggles, and charts are named for assistive tech, and yellow,
  cyan, and emerald state text is darkened in light mode to meet contrast requirements.

- [Jobs] Browse and delete archived jobs

  A toggled `archive` mode lists jobs from the Pro archive table with the same filtering, search,
  and deletion as live jobs.

- [Jobs] Group, link, and steady the jobs chart

  Grouping follows filters or an explicit `Group` choice, series use a stable palette with a
  legend, clicking a series filters the list, and the tooltip sits beside the hovered column.

- [Jobs] Make the sidebar stateful and persistent

  The queue count column follows the selected state, collapsed sections are remembered, queue rows
  link to their detail page, and state deep links select the right state on first render.

- [Jobs] Show chunk leaders and members in job views

  Running chunks appear as a combined unit in the executing view, siblings are marked with their
  leader elsewhere, and a `chunks:` filter shows every member of a chunk.

- [Jobs] Highlight chains and backfills on jobs

  Chains and backfills show a badge on the jobs table, and job details link to related jobs in the
  sequence with their execution state.

- [Jobs] Confirm bulk actions with visible filters

  Bulk cancel, retry, run, delete, and queue stop ask for confirmation with a sentence naming how
  many jobs are affected, their state, and the active filters. Selections survive loading more rows
  or changing the sort, reaching the bulk action limit explains that select all can be repeated,
  and select all honors a resolver's custom `bulk_action_limit`.

- [Jobs] Keep the jobs header sticky and selections visible

  Search, sort, and bulk actions stay reachable while scrolling, selected rows are tinted, and
  clicking the header checkbox with a partial selection completes the visible page instead of
  clearing it.

- [Jobs] Name the active state and time column

  The heading shows which state the rows belong to, and the time column header says what its value
  means for that state, such as Running, Next retry, or Finished.

- [Job Details] Support externally stored recorded output

  Recorded output is fetched through Pro's storage backend, so jobs recorded to an external store
  show their output rather than a storage key. External output loads on demand, and the panel
  reports stored size and distinguishes nothing recorded, missing output, and an unreachable
  backend.

- [Job Details] Display process PID in job diagnostics

  Executing Pro jobs show the process PID alongside the node and status.

- [Pruners] Add pruners page for managing retention rules

  Pro v1.8 pruning rules are listed with their precedence, match, and retention details, and can
  be reordered, edited inline, or created from a side drawer. Concurrent edits are recovered
  gracefully rather than discarding work in progress.

- [Queues] Sharpen the queues index for triage

  Queue counts are split into available, scheduled, and retryable columns with state dots that
  link into the jobs list. Bare search filters by queue name, sorting by counts and executing
  works, paused or terminating queues show in amber, and bulk action toasts name the queues they
  touched.

- [Queues] Support per node scaling for global limits

  Global limits with `per_node: true` are read from producer checks and preserved when editing.
  The global limit stat distinguishes "N cluster-wide" from "N per node", and queue totals scale
  with node count so utilization reflects real capacity.

- [Resolver] Add `recorded_size_limit/0` resolver callback

  Caps rendered recorded output at 256kb by default. Decoding also follows the job's
  `safe_decode` setting instead of always forcing `:safe`.

- [Workflows] Support workflow compensations

  Compensations roll back completed steps when a workflow fails. Workflow details gain a
  compensation section reporting rollback state and jobs, compensations appear in the index under
  the workflow they roll back, and a new `kinds:` qualifier filters them in or out.

- [Workflows] Make the workflows index accurate and scannable

  Progress shows each state instead of hiding failures inside a "finished" segment, activity
  counts only what exists, rows needing attention carry an edge cue, and status agrees with the
  started and duration columns.

- [Workflows] Improve workflow detail legibility and safety

  The graph sizes to its content and opens on the running or first failed step, with
  keyboard-focusable nodes. Cancel and Retry confirm before acting, disable when nothing applies,
  and report affected counts.

- [Workflows] Look up origin names after the workflow limit

  The index joined every root against its origin before sorting, even though only compensations
  have an origin. A correlated subquery now runs for the visible rows alone, cutting used buffers
  by more than half on an index with thousands of workflows.

### Changes

- [Crons] Remove the worker sort from the crons index

  The name sort now orders by handler and then entry name, so entries that share a worker stay
  adjacent without a separate sort.

- [Dashboard] Title detail pages consistently

  Each detail heading and browser title reads as the name followed by its kind, and create pages
  use the same wording as their forms.

- [Jobs] Remove the "full" count option from the jobs chart

  The count series rarely changed and the sidebar already carries those numbers.

### Bug Fixes

- [Crons] Fix slow crons page load on Postgres

  Fetching cron history caused a full table backward scan for every entry, taking multiple seconds
  on large tables. The history query filters before sorting so Postgres uses the index, while
  remaining compatible with CockroachDB.

- [Crons] Evaluate next run in the entry's timezone

  A `0 9 * * *` entry zoned to Chicago now shows a 9am local fire rather than 9am UTC.

- [Dashboard] Restore Inter and Menlo fonts after the Tailwind v4 upgrade

  The theme declared fonts with names Tailwind v4 no longer uses, so every page silently fell back
  to the system font.

- [Dashboard] Fix refresh shortcut toggling twice per press

  The shortcut listener stacked on every reconnect, so `r` flipped refresh off and back on
  immediately. Toggling off now cancels the pending timer.

- [Dashboard] Raise a descriptive error for denied actions

  Enforcing access raised `AccessError` without a message, which failed during formatting and
  obscured the cause. The error now names the denied action and the access level that disallows
  it.

- [Dashboard] Respect `resolve_instances/1` for stashed and default instances

  Instance selection honors the resolver for the default instance, and the default telemetry
  logger reports the actual instance name instead of always logging `Oban`.

- [Jobs] Refresh the jobs chart on every tick

  The chart only re-queried when the page's second-resolution timestamp changed, so refreshes
  landing in the same second were skipped.

- [Jobs] Keep chart selection between navigated pages

  Chart settings are mirrored into mounted state and read fresh on every join, so they survive a
  remount.

- [Job Details] Disable job detail actions without access

  Cancel, retry, delete, and edit buttons are gated on resolver access, matching the queues and
  workflows pages. Previously read only users saw enabled buttons that did nothing when clicked.

- [Queues] Use fixed buckets for the queue detail sparkline

  Idle periods were compressed away, so buckets minutes apart rendered as neighbors and every axis
  label showed the same time. History now spans the full lookback window with a zero count where
  nothing executed.

- [Workflows] Add partial-index predicate to sub-workflow parent subquery

  The parent dependency subquery lacked the `meta ? 'workflow_id'` predicate, so Postgres couldn't
  use the partial workflow index and scanned the jobs table instead.
