# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Additions

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

[Unreleased]: https://github.com/sorentwo/oban_web/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/sorentwo/oban_web/compare/v0.8.0...v1.0.0
[0.8.0]: https://github.com/sorentwo/oban_web/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/sorentwo/oban_web/compare/v0.6.3...v0.7.0
[0.6.3]: https://github.com/sorentwo/oban_web/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/sorentwo/oban_web/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/sorentwo/oban_web/compare/v0.6.0...v0.6.1
