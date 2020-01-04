# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

## Additions

- Add detail modal for inspecting job arguments, errors and state timings.

## [v0.6.3] 2019-12-15

## Changes

- Display duration or distance in words depending on job state. This clarifies
  timestamp information. Relative timestamps have an formatted absolute value as
  the "title" attribute as well.

- Improved ordering for various job states. Many states were reversed, making
  the table view seem broken.

## Fixes

- Ensure all assigns are available on render when a disconnected node
  reconnects. This fixes an issue when viewing the UI in development.

## [v0.6.2] 2019-12-05

## Changes

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

## Fixes

- Ignore the stats server when queues is empty.

[Unreleased]: https://github.com/sorentwo/oban_web/compare/v0.6.3...HEAD
[0.6.3]: https://github.com/sorentwo/oban_web/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/sorentwo/oban_web/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/sorentwo/oban_web/compare/v0.6.0...v0.6.1
