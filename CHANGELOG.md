# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

## [V1.1.2] 2020-02-07

### Fixes

- Correct syntax used for descheduling and discarding jobs

- Set the `discarded_at` timestamp when discarding jobs

## [V1.1.1] 2020-02-06

### Fixes

- Fix job detail refreshing on `tick` events

## [v1.1.0] 2020—02—06

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

## [v1.0.1] 2020-01-29

### Fixes

- Display `discarded_at` time in detail timeline view.
- Prevent jitter when clearing stats cache.

## [v1.0.0] 2020-01-29

### Changes

- Upgrade Oban and set dependency to `~> 1.0.0`
- Update stats and the queries that power stats to rely on more frequent
  refreshes and fewer database calls. The average refresh time dropped from
  `~310ms` to `~180ms`.

## [v0.8.0] 2020-01-23

### Changes

- Upgrade to LiveView `~> 0.5` and test with `0.6`.

## [v0.7.0] 2020-01-08

### Added

- Add detail modal for inspecting job arguments, errors and state timings.

## [v0.6.3] 2019-12-15

### Changes

- Display duration or distance in words depending on job state. This clarifies
  timestamp information. Relative timestamps have an formatted absolute value as
  the "title" attribute as well.

- Improved ordering for various job states. Many states were reversed, making
  the table view seem broken.

### Fixes

- Ensure all assigns are available on render when a disconnected node
  reconnects. This fixes an issue when viewing the UI in development.

## [v0.6.2] 2019-12-05

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

## [v0.6.1] 2019-11-22

### Fixes

- Ignore the stats server when queues is empty.

[Unreleased]: https://github.com/sorentwo/oban_web/compare/v1.1.2...HEAD
[1.1.2]: https://github.com/sorentwo/oban_web/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/sorentwo/oban_web/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/sorentwo/oban_web/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/sorentwo/oban_web/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/sorentwo/oban_web/compare/v0.8.0...v1.0.0
[0.8.0]: https://github.com/sorentwo/oban_web/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/sorentwo/oban_web/compare/v0.6.3...v0.7.0
[0.6.3]: https://github.com/sorentwo/oban_web/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/sorentwo/oban_web/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/sorentwo/oban_web/compare/v0.6.0...v0.6.1
