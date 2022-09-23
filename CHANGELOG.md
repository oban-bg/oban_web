# Changelog for Oban Web v2.9

All notable changes to `Oban.Web` are documented here.

## Encrypted, Structured, and Recorded Support

Jobs that use `Oban.Pro.Worker` features like encryption, recording, and
enforced structure now display an indicator on the details page. What's more,
recorded jobs display the job's return value directly in the details page.

## v2.9.5 — 2022-09-23

- [Web] Expand version requirements to allow Phoenix Live View `0.18`

- [Telemetry] Make JSON encoding optional for default logger.

  `Telemetry.attach_default_logger/1` now supports an `:encoded` option to
  use structured logging rather than automatic JSON encoding.

- [Web] Clear `id` param when navigating away from detail view

  After loading the detail view the sidebar navigation wouldn't function because
  the URL retained an `id` param. Now the sidebar paths always omit the `id`
  param, regardless of when they originally rendered.

## v2.9.4 — 2022-08-10

### Bug Fixes

- [Queues Page] Correctly display the current global limit in expanded queues.

- [Queues Page] Correctly parse and format rate limits that use the new unix
  timestamp format.

## v2.9.3 — 2022-07-26

Most fixes in this release are targeted at the recent Oban Pro v0.12 release.
_Users on earler versions of Pro, or without Pro, don't need to upgrade._

### Bug Fixes

- [Jobs Sidebar] Correctly display global symbol and current limit

- [Queues Page] Correctly display the current global limit

- [Queues Page] Prevent displaying negative rate limits

  Gaps between execution that exceed the configured period, within one or more
  partitions, could result in an incorrect, negative rate limit.

## v2.9.2 — 2022-06-27

### Bug Fixes

- [Jobs Detail] Correct duration formatting for milliseconds

  Negative numbers displayed with much larger values than they should have
  because they lacked an `abs` call. In addition, the lack of padding caused 5ms
  to look like 500ms.

- [Resolver] Loosen resolver check to avoid compliation issues

  The interplay of router compilation and code reloading could cause "invalid
  :resolver" errors during recompliation during development.

## v2.9.1 — 2022-03-03

### Bug Fixes

- [Jobs Page] Display correct global count in the sidebar. Now, global queues
  will show a single global value rather than global * nodes.

## v2.9.0 — 2022-02-13

### Enhancements

- [Jobs Page] Switch to a more intuitive default sort mode for all states. Now,
  only `available`, `scheduled`, and `retryable` jobs are sorted in ascending
  order by default.

- [Job Details] The errors list in job details provides an absolute timestamp on
  hover, along with the relative timestamp that's always shown. The errors list
  got some additional formatting love to improve readability.

### Bug Fixes

- [Job Details] Restore missing color to the timeline component for `retryable`
  or `scheduled` states

For changes prior to `2.9` see the Oban [2.10][prev] docs.

[prev]: https://hexdocs.pm/oban/2.10.1/changelog.html
