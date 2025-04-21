# Changelog for Oban Web v2.11

All notable changes to `Oban.Web` are documented here.

## 🥂 Web is Free and Open Source

Oban Web is now [fully open source][fos] and free (as in champagne 😉)! From now on, Oban Web will
be [published to Hex][hex] and available for use in your Oban powered applications. See the
updated, much slimmer, [installation guide][ins] to get started!

Web v2.11 is licensed under Apache 2.0, just like Oban and Elixir itself. Previous versions are
commercially licensed, therefore private, and won't be published to Hex.

Special thanks to all of our customers that supported the project for the past 5 years and made
open source Oban, and now Web, possible 💛.

[fos]: https://github.com/oban-bg/oban_web
[hex]: https://hex.pm/packages/oban_web
[ins]: installation.md

## 🐬🪶 MySQL and SQLite

All official Oban and Oban Pro engines are fully supported. Listing, filtering, ordering, and
searching through jobs works for Postgres, MySQL, and SQLite. That includes the particularly
gnarly issue of dynamically generating and manipulating JSON for filter auto-suggestions! Nested
args queries, such as `args.address.city:Edinburgh` work equally well with each engine.

## 🎛️ Instance Select

The dashboard will now support switching between Oban instances. A new instance select menu in the
header allows switching between running Oban instances at runtime. There's no need to mount
additional dashboards in your application's router to handle multiple instances. The most recently
selected instance persists between mounts.

```diff
- oban_dashboard "/oban_a", oban_name: Oban.A
- oban_dashboard "/oban_b", oban_name: Oban.B
- oban_dashboard "/oban_c", oban_name: Oban.C
+ oban_dashboard "/oban"
```

This also eliminates the need for additional router configuration, as the dashboard will select
the first running Oban instance it finds (with a preference for the default `Oban`).

```diff
- oban_dashboard "/oban", oban_name: MyOban
+ oban_dashboard "/oban"
```

## ☯️ Unified Tables

The queue and jobs tables are fully rebuilt with shared, reusable components and matching
functionality. This makes interacting with jobs clearer while queues gain some much requested
functionality:

* Sidebar - a new queue sidebar shows status counts and enables filtering by statuses such as
  `paused` or `terminating`.

* Filtering - queues are auto-complete filterable just like jobs, making it possible to find
  queues running on a particular node or narrow down by status.

* Shared Sorting - queue sorting now behaves identically to jobs, through a shared dropdown. 

* Uniform Navigation - click on any part of the queue row to navigate to details.

* Condensed Rows  - simplify the queue page by removing nested row components. Extra queue details
  are in the sub-queue page.

## 🕯️ Operate on Full Selection

Apply bulk actions to all selected jobs, not just those visible on the current page.

This expands the select functionality to extend beyond the current page and include all filtered
jobs, up to a configurable limit. The limit defaults to 1000 and may be overridden with a [resolver
callback][rsc].

[rsc]: Oban.Web.Resolver.html#c:bulk_action_limit/1

## v2.11.3 - 2025-04-21

### Bug Fixes

- [Installer] Prevent compilation errors when igniter isn't installed.

## v2.11.2 - 2025-04-21

### Enhancements

- [Installer] Add igniter powered `oban_web` installer.

  It's now possible to install oban_web with a single igniter command:

  ```bash
  mix igniter.install oban_web
  ```

  Or install `oban` and `oban_web` at the same time:

  ```bash
  mix igniter.install oban,oban_web
  ```

- [Resolver] Pattern match on `arg` rather than checking for `decorated` annotation.

  Matching on term encoded `arg` is more accurate than checking for decorated metadata. This makes
  the default `format_job_args` compatible with workflow cascade jobs that don't have any `arg`
  set.

- [Page] Upgrade bundled assets to use the Phoenix LiveView JavaScript version to v1.10

- [Chart] Replace inline styles with tailwind classes to avoid inline style CSP warnings.

## v2.11.1 — 2025-02-06

### Enhancements

- [Layout] Display Oban.Met version in layout footer

  The Met version is highly relevant to how Web behaves. This also refactors the version display
  for reuse with consistent conditionals.

- [Layout] Only show Pro version number when available.

  The version footer shows that Pro isn't available rather than showing a `v` followed by a blank
  space.

- [Jobs] Auto-complete worker priorities from 0 to 9

  Priority completion only matched values from 0..3, but the full range is 0..9.

### Bug Fixes

- [Jobs] Preserve quotes in `args` and `meta` searches.

  Parsing would strip quotes from args and meta queries. This prevented quoted numeric vaalues to
  be treated as integers. Now quotes are preserved for `args` and `meta`, just as they are for
  other qualifiers.

- [Queue Details] Eliminate duplicate id warnings for inputs in queue details.

  The latest live_view alerts when nodes in a view have conflicting ids, which caught a number of
  instances on the queue details page.

- [Queues] Fix duplicate ids for nodes and queues in sidebar.

- [Search] Correct assigns typo in search component handler.

  The key is `assigns`, not `asigns`.

- [Resolver] Fix resolver access typespec.

  Access options must be a keyword list with boolean values, not just a list of option atoms.

## v2.11.0 — 2025-01-16

### Enhancements

- [Dashboard] Load using non-default Oban instance without any config.

  The dashboard now loads the first running non-default Oban instance, even without anything
  configured.

- [Jobs] Decode decorated `arg` when formatting job args.

  The decorated `arg` are term encoded and inscrutiable in the standard display. Now the value is
  decoded and display as the original value.

- [Jobs] Prevent decoding executable functions when displaying `recorded` output.

  By default, recorded content uses the `:safe` flag, which now prevents both atom creation and
  executable content. This is an extra security precaution to prevent any possible exploits
  through Web.

- [Queues] Add sidebar similar to the jobs table, including filters to make bulk operations on
  queues possible.

- [Queues] Add search bar with filtering functionality to query queues.

- [Queues] Add multi-select mode to allow operating on multiple queues at once.

- [Queues] Expose a "Stop Queues" operation along with corresponding access controls to prevent
  unintended shutdown.

- [Resolver] Add `resolve_instances/1` callback to restrict selectable Oban instances.

  Not all instances should be available to all users. This adds the `resolve_instances/1` callback
  to allow scoping instances by user:

  ```elixir
  def resolve_instances(%{admin?: true}), do: :all
  def resolve_instances(_user), do: [Oban]
  ```

- [Resolver] Add `bulk_action_limit/1` to restrict the number of jobs operated on at once.

  Bulk operations now effect all filtered jobs, not just those visible on the current page. As
  there may be millions of jobs that match a filter, some limiting factor is necessary. The
  default of 1000 may be overridden:

  ```elixir
  def bulk_action_limit(:completed), do: 10_000
  def bulk_action_limit(_state), do: :infinity
  ```

### Bug Fixes

- [Page] Address deprecations from recent upgrades to Elixir 1.17+, Phoenix 1.5+, and Phoenix
  LiveView 1.0+

- [Jobs] Always treat args wrapped in quotes as a string when filtering.

  Manually wrapping values in quotes enforces searching by string, rather than as a parsed
  integer. As values are cast to JSON the type matters, and `123 != "123"`.
