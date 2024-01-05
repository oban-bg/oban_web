# Changelog for Oban Web v2.10

All notable changes to `Oban.Web` are documented here.

## 📊 Charts

Charts for realtime metrics are enabled out of the box without any external dependencies. Charts
are helpful for monitoring health and troubleshooting from within Oban Web because not all apps
can, or will, run an extra timeseries or metrics database. And, because they're displayed
alongside the original jobs, you can identify outliers in aggregate and then drill into individual
jobs.

#### Highlights

* Select between execution counts, full counts, execution time, and wait time
* Aggregate time series by state, node, worker, or queue label
* Rollup metrics by time from 1s to 2m, spanning 90s to 3h of historic data
* Measure execution and wait times across percentiles, from 100th down to 50th at standard
  intervals

## 🔍 Filtering

Filtering is entirely overhauled with a new auto-complete interface, new qualifier syntax, and
vastly more performant queries. Full text searching with unindexable operators such as `ilike` and
`tsvector` was removed in favor of highly optimized exact-match queries. With the new query
syntax all searching is faster, and searching nested `args` is over 100x faster thanks to index
usage.

One additional performance improvement for large `oban_jobs` tables is threshold querying. In
order to minimize load on the application's database, only the most recent 100k jobs
(approximately) are filtered. The 100k limit can be disabled or configured for each state, i.e. you
could restrict filtering `completed` jobs but access the full history of `cancelled` jobs.

#### Highlights

* Filter by args, meta, node, priority, queue, tags, and worker
* Typeahead with keyboard shortcuts for focusing, selecting, and completing suggestions
* Highly optimized suggestion queries across a configurable number of recent jobs
* Locally cached for immediate feedback and minimal load on your application database
* Auto-completion of nested `args` and `meta` keys and values at any depth 

## ⏱️  Metrics

The foundation of charts, filtering, optimized counts, and realtime monitoring is the new
`Oban.Met` package. It introduces a distributed time-series data store and replaces both
`Oban.Plugins.Gossip` and `Oban.Web.Plugins.Stats` with zero-config implementations that are much
more efficient.

#### Highlights

* Telemetry powered execution tracking for time-series data that is replicated between nodes,
  filterable by label, arbitrarily mergeable over windows of time, and compacted for longer
  playback.
* Centralized counting across queues and states with exponential backoff to minimize load and
  data replication between nodes.
* Ephemeral data storage via data replication with handoff between nodes. All nodes have a shared
  view of the cluster's data and new nodes are caught up when they come online.

In the future `Oban.Met` modules will be public, documented, and available for use from your own
applications.

## ❤️‍🩹 Deprecations

- The `Oban.Web.Plugins.Stats` plugin is no longer necessary and you can remove it from
  your plugins:

  ```diff
  plugins: [
  - Oban.Web.Plugins.Stats,
  ...
  ```

- The `Oban.Plugins.Gossip` plugin is no longer necessary and you should remove it from your
  plugins:

  ```diff
  plugins: [
  - Oban.Plugins.Gossip,
  ...
  ```

## v2.10.2 — 2023-01-05

### Enhancements

- [Jobs] Use the queue producer's uuid when checking for orphaned jobs

  The node alone isn't accurate enough to indicate orphans because queues may start, stop, or
  crash unexpectedly. Now that all engines include the `uuid` as part of the `attempted_by` array,
  we can reliablity use it to detect orphaned jobs.

- Support using `phoenix_html` 4.0

  The latest release Phoenix.HTML removes the top-level `use` macro and some common functionality.
  This changes allows using the older v3.3 release or v4.0, with the necessary internal changes to
  handle either.

## v2.10.1 — 2023-12-01

### Bug Fixes

- [Resolver] Mount resolvers without an optional `resolve_access/1` callback defined.

- [Query] Prevent `to_existing_atom/1` errors when querying jobs by ensuring job state atoms are
  loaded before any jobs run.

- [Query] Correct appending filter choices with both a qualifier and dot separator.

  Clicking or tab completing a qualified term and a dot would incorrectly construct a compound
  term. Now, completing a partial filter like `workers:MyApp.Al` correctly returns
  `workers:MyApp.Alpha` instead of the broken `workers:MyApp:MyApp.Alpha`.

- [Job Details] Prevent cancelled and discarded icons from rotating in completed state

## v2.10.0 — 2023-10-12

### Enhancements

- [Jobs] Append and submit filter suggestions on click

  Previously, clicking a suggested value injected it into the input but didn't submit it as a
  filter. That was unexpected, and led to an odd "deletion" of previous values when typing
  multiple filters at once. Clicking on a suggested value immediately submits it as a filter now.

- [Jobs] Improved json path suggestions

  Auto submission exposed an issue with json path completion, i.e. path suggestions lacked a final
  `:` or `.` to indicate if it was a full qualifier or part of a path. Now it's clear whether an
  `args` or `meta` suggestion is part of a nested object path (`.`), or a final key (`:`).

- [Jobs] Add filtering by a list of ids, e.g. `ids:1,2,3`

  It turns out this is a commonly used feature, especially in a staging environment and by testing
  teams.

### Bug Fixes

- [Resolver] Only use a conservative query limit for `completed` jobs

  Due to the loose application of threshold queries, the 100k limit caused confusion for other
  states with only a handful of jobs, e.g. `retryable`. Now the limit is only applied to
  `completed` jobs by default and `:infinity` for all other states.

- [Jobs] Parse entire term as an integer when filtering

  Values, such as UUIDs that start with a digit, were incorrectly considered an integer and
  couldn't be used in filtering.

- [Job Details] Prevent cancelled/discarded jobs showing completed

  The timeline component incorrectly displayed jobs that weren't completed or executing as
  completed.

## v2.10.0-rc.3 — 2023-09-24

### Enhancements

- [Resolver] Prevent dashboard access with :forbidden access

  The dashboard now offers authentication by checking access on mount via `resolve_access/1`.
  Returning `{:forbidden, path}` will halt mounting and redirect to the specified path.

  By combining `resolver_user/1` and `resolve_access/1` callbacks it's possible to build an
  authenticaiton solution around the dashboard. For example, this resolver extracts the
  `current_user` from the conn's assigns map and then scopes their access based on role. If it is
  a standard user or `nil` then they're redirected to `/login` when the dashboard mounts.

  ```elixir
  defmodule MyApp.Resolver do
    @behaviour Oban.Web.Resolver

    @impl true
    def resolve_user(conn) do
      conn.assigns.current_user
    end

    @impl true
    def resolve_access(user) do
      case user do
        %{admin?: true} -> :all
        %{staff?: true} -> :read_only
        _ -> {:forbidden, "/login"}
      end
    end
  end
  ```

- [Jobs] Change default sort direction for completed states

  Completed, cancelled, and discarded states used an unintuitive sort preference with oldest jobs
  first. Now it's restored to the historic ( and more intuitive) order of newest jobs first.

- [Deps] Loosen constraints to allow Phoenix LiveView v0.20 and above

- [Deps] Require a minimum of Oban Met v0.1.2 and above

### Bug Fixes

- [Chart] Correct count estimation for values between 1k and 10k

- [Job Details] Make detail times relative on demand.

  Job details always showed `-` because the old `relative_` timestamp fields were removed. Now
  details show the correct relative timestamp, including a fix to correctly show the timing and
  duration for completed jobs.

- [Chart] Use `sum` for exec counts and `max` for full counts to display accurate information when
  rolling up values by periods greater than 1s. Previously, full counts were summed across time
  windows.

## v2.10.0-rc.2 — 2023-08-22

Let's try this one more time...

- [Assets] Inline assets and track them as external resources rather than loading on them at
  runtime.

## v2.10.0-rc.1 — 2023-08-22

### Bug Fixes

- [Assets] Correctly resolve assets directory across all build environments.

  A change to loading assets dynamically at runtime broke path resolution in release builds.

## v2.10.0-rc.0 — 2023-08-21

### Changes

- Require a minimum of Elixir v1.13 for compatibility with features required by `oban_met`

- Require a minimum of Phoenix v1.7 to support verified routes.

- Require a minimum of Phoenix LiveView v0.19 for various features and bug fixes.

### Enhancements

#### Navigation

- [PubSub] Indicate when PubSub isn't connected or receiving notifications with a warning and
  explanation

- [Refresh] Persist refresh selection between sessions and resume the most recent value after
  pausing on window blur

- [Themes] Support selecting light, dark, or system theme via a dropdown menu

- [Shortcuts] Introduce keyboard shortcuts modal that's accessible by pressing `?`

- [Shortcuts] Add shortcuts to toggle refreshing, cycle themes, focus search, and navigate between
  pages

#### Charts

- Display canvas based charts for exec count, full count, exec time, and queue time

- Restore chart options on page reload, including whether it's collapsed

- Indicate which filters are applied when charts are filtered

- Limit plotting large series, e.g. `queues` or `workers` to the 7 highest activity
  series. Without limitation charts are slow and unreadable.

- Estimate counts and times to a fixed size with a unit suffix

#### Jobs Page

- Restrict filtering and searching to a configurable maximum number of jobs. The default is
  100k, which can be disabled or customized with a resolver callback.

- Calculate all relative timestamps on the client to minimize updates over the wire

- Reimplement jobs list view with simpler components without per-column sorting for better
  performance.

- Use a dropdown menu for job sorting to more clearly indicate which field is used for
  sorting and the sort direction.

- Orphans, jobs stuck in an executing state, are now marked with an status indicator

#### Sidebar

- Elevate "States" to the top of the sidebar and visually clarify that they're for navigation
  while "Nodes" and "Queues" are filters.

- Always display a standard toggle icon rather than showing one on hover

- Use counts reported by `oban_met`. Counts are only reported by a single node and larger
  queue/state combinations are counted with exponential backoff.

- Removed from the queues page to maximize table space

- Reduce param tracking and Use `patch` rather than `navigate` on links for filter changes without
  a full update

#### Resolver

- Add `jobs_query_limit/1` callback to control the maximum number of jobs to query when filtering,
  searching, or generally listing jobs

- Add `hint_query_limit/1` callback to control the number of recent jobs to search for
  auto-complete hints.

### Bug Fixes

- [Queues] Correctly handle toggling global limits on and off

- [Queues] Track global limit changes on edit without requiring increment or decrement

- [Web] Prevent lingering tooltips by by destroying instances on unmount
