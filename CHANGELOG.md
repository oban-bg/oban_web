# Changelog

All notable changes to `Oban.Web` will be documented in this file.

## v2.0.0-alpha.0

### Changes

- Upgrade to Oban `2.0.0-rc.1`, LiveView `~> 0.13`, and add a dependency on Oban
  Pro.

- Introduce `Oban.Web.Router` for more convenient and flexible dashboard routing.
  The new module provides an `oban_dashboard/2` macro, which prevents scoping
  mistakes and provides the foundation of better route support.

  Here is how to mount a dashboard at `/oban` with the new macro:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        import Oban.Web.Router

        scope "/", MyAppWeb do
          pipe_through [:browser]

          oban_dashboard "/oban"
        end
      end

- Add bulk actions for all jobs in table view. It's now possible to select one
  or more jobs in the table and then cancel, run, retry or delete them all.

- Add a dropdown that controls the refresh rate of jobs and stats in the
  dashboard. Lowering the refresh rate can reduce query overhead, or pause
  updates entirely.

- Expose pause/resume controls and a slider for scaling in the queue side bar.

- Eliminate migrations. Migrations are no longer necessary for updates or
  full text searching. You may safely undo previous migrations.

- Consider job `tags` along with `args` and worker name when searching.

- More intelligent search using "and", "or" and respecting parenthesis.

- Consistently toggle filters on and off from the sidebar, rather than matching
  on a filter list in the header.

## v1.5.0 — 2020-04-27

### Changes

- Upgrade to Phoenix `~> 1.5`, LiveView `~> 0.12` and PubSub `~> 2.0`. None of
  these upgrades required changes to ObanWeb, they are meant to enable upgrades
  for host applications.

## v1.4.0 — 2020-03-24

### Changes

- Upgrade to LiveView `~> 0.10` along with requisite changes to use
  `@inner_content` in the layout template. This prevents the view from hanging
  with a blank screen on load.

## v1.3.1 — 2020-03-18

### Fixed

- Prevent `FunctionClauseError` when closing the dashboard before it has
  finished mounting.

## v1.3.0 — 2020-03-10

### Changes

- Upgrade to LiveView `~> 0.9` along with the requisite changes to `flash`
  handling. Note, this requires pipelines in the host app to use
  `fetch_live_flash` instead of `fetch_flash`.

## v1.2.0 — 2020-02-07

### Fixes

- Prevent flash map key issue on initial mount. The lack of a `show` key on the
  empty flash map caused runtime errors.

- Prevent losing stats cache on restart by shifting table ownership into the
  supervisor.

### Changes

- Clear `completed_at` and `discarded_at` timestamps when descheduling jobs.

- Upgrade to LiveView `~> 0.7`.

### Added

- Display job `priority` value in the table and detail views.

- Display job `tags` in the detail view.

## v1.1.2 — 2020-02-07

### Fixes

- Correct syntax used for descheduling and discarding jobs

- Set the `discarded_at` timestamp when discarding jobs

## v1.1.1 — 2020-02-06

### Fixes

- Fix job detail refreshing on `tick` events

## v1.1.0 — 2020—02—06

### Changes

- Add `verbose` setting to control log levels. This command mirrors the behavior
  in Oban and is respected by all queries.

- Deprecate `stats` configuration. The stats module is entirely overhauled so
  that it only refreshes when one or more users are connected. That prevents it
  from using any connections or performing any queries while testing, which
  renders the `stats` option pointless.

- Add `stats_interval` to control how often node and queue counts are refreshed.
  The default value is every 1s.

- Add `tick_interval` to control how often the jobs table and job details are
  refreshed. The default value is every 500ms.

## v1.0.1 — 2020-01-29

### Fixes

- Display `discarded_at` time in detail timeline view.
- Prevent jitter when clearing stats cache.

## v1.0.0 — 2020-01-29

### Changes

- Upgrade Oban and set dependency to `~> 1.0.0`
- Update stats and the queries that power stats to rely on more frequent
  refreshes and fewer database calls. The average refresh time dropped from
  `~310ms` to `~180ms`.

## v0.8.0 — 2020-01-23

### Changes

- Upgrade to LiveView `~> 0.5` and test with `0.6`.

## v0.7.0 — 2020-01-08

### Added

- Add detail modal for inspecting job arguments, errors and state timings.

## v0.6.3 — 2019-12-15

### Changes

- Display duration or distance in words depending on job state. This clarifies
  timestamp information. Relative timestamps have an formatted absolute value as
  the "title" attribute as well.

- Improved ordering for various job states. Many states were reversed, making
  the table view seem broken.

### Fixes

- Ensure all assigns are available on render when a disconnected node
  reconnects. This fixes an issue when viewing the UI in development.

## v0.6.2 — 2019-12-05

### Changes

- Add support for explicitly disabling stats rather than inferring based on
  queue configuration. This prevents issues in production environments where
  certain nodes (i.e. web) aren't processing any queues, but the the UI is
  accessed.

  ObanWeb configuration now differs from Oban configuration and you'll need to
  specify it separately. Specify the `repo` in `config.exs`:

  ```elixir
  config :my_app, ObanWeb, repo: MyApp.Repo
  ```

  Disable the stats tracker in the test environment:

  ```elixir
  config :my_app, ObanWeb, stats: false
  ```

## v0.6.1 — 2019-11-22

### Fixes

- Ignore the stats server when queues is empty.
