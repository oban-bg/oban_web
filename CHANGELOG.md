# Changelog for Oban Web v2.9

All notable changes to `Oban.Web` are documented here.

## Encrypted, Structured, and Recorded Support

Jobs that use `Oban.Pro.Worker` features like encryption, recording, and
enforced structure now display an indicator on the details page. What's more,
recorded jobs display the job's return value directly in the details page.

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
