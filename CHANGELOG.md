# Changelog

All notable changes to `Oban.Web` are documented here.

## v2.8.2 — 2021-12-01

### Fixed

- Restore previous "Run Now" functionality for scheduled jobs. Oban's built-in
  function ignores the `scheduled` state, which prevented the intended
  functionality.

- Use whitespace and wrapping when displaying args and meta on the job details
  page. Overflowing was restrictive, and often broken. The new styling matches
  that of error reporting services.

- Indicate that jobs are complete, rather than just attempted in the details
  timeline.

## v2.8.1 — 2021-11-24

### Fixed

- Ensure all required params are available when navigating job pages.

  When a job was deleted, either manually or automatically, the params weren't
  initialized properly. By consistently routing back to the base jobs page we
  ensure that all keys are available.

- Clean up tooltip warnings caused by missing ids.

  Some elements declared a phx-hook without providing an id. That caused
  console errors and prevented unmounting in-use tooltips.

## v2.8.0 — 2021-11-19

### 📋 New Queues Table, Details, and Runtime Configuration

Oban Web has a new queues page that shows details about every active queue,
including previously invisible configuration like global concurrency limits,
uptime, and rate limit activity. You can also expand queues to view specifics
about instances across each node, along with the ability to pause or resume
instances.

For more queue information and runtime configuration there is a details page for
every queue. Within it you can scale the local limit across all nodes, change
the global limit, edit the rate limit, and even scale individual instances.

### 🌗 Dark Mode and Visual Updates

The dashboard is completely overhauled with a visual refresh and a new dark
mode! The visual changes were driven by accessibility improvements such as:

- Increased contrast
- Consistent hover/focus for actionable elements
- Informative tooltips
- Semantic forms

### 🔏 Custom Args/Meta Formatting Callbacks

By default, the job views pretty print `args` and `meta` in full. For more
control, i.e. for privacy or brevity, there are now `format_job_args/1` and
`format_job_meta/1` callbacks.

For example, to redact the `"email"` for only the `SecretJob` worker:

```elixir
@impl true
def format_job_args(%Oban.Job{worker: "MyApp.SecretJob", args: args}) do
  args
  |> Map.replace("email", "REDACTED")
  |> inspect(pretty: true)
end

def format_job_args(job), do: Oban.Web.Resolver.format_job_args(job)
```

See the [Customizing the Dashboard](web_customizing.html) guide for more.

### Enhancements

#### Dependencies

- Upgrade the minimum Phoenix Live View dependency to `0.17.4` in order to get
  components working properly.

- Upgrade the minimum Elixir version to `1.12` due to the required use of HEEX
  templates in the latest Live View.

#### Jobs Page

- Sort jobs by worker, queue, attempt, or time in either ascending or
  descending order. The default is by time ascending.

- Filter jobs by multiple nodes or queues at once. Within nodes or queues
  filtering acts like an "OR", while between them it is an "AND".

#### Performance

- Pause refreshing when Web loses window visiblity and restore it when the
  window becomes visible again. This prevents runaway database queries when
  the tab is left open unattended. Additionally, there is a new 1 minute
  refresh option for even less frequent polling.

- Perform stats counts less frequently for large states to minimize database
  load. This trades realtime fidelity for performance by backing off of counts
  that can't be accelerated by an index. State counts are displayed as
  suffixed estimates, e.g. `41k` or `43.1k` to compensate.

- Fetch only fields that may change when refreshing the jobs table or details
  view.

- Use the built-in `cancel_all`/`retry_all` from Oban to accelerate bulk
  operations.

#### Formatter

- Export `locals_without_parens` for `oban_dashboard/1,2` in `.formatter.exs`

## v2.7.4 — 2021-09-27

### Fixed

- Safely assign state from params when re-mounting to prevent a missing key
  error.

## v2.7.3 — 2021-09-15

### Changed

- Expose documented, but unfortunately hidden, `socket_path` option.

  The socket path is no longer hard coded as `/live`. It is now possible to
  configure an alternate path when mounting the dashboard.

### Fixed

- Guard against `nil` global limit when calculating sidebar stats.

## v2.7.2 — 2021-08-13

### Changed

- Upgrade minimum Phoenix Live View dependency to `0.16`.

## v2.7.1 — 2021-06-01

### Fixed

- Guard agaisnt empty params on initial render when the dashboard is re-mounted.

### Added

- Add `id:` qualifier for id and multiple id based searching.

## v2.7.0 — 2021-05-25

### Enhanced Search Syntax

Job search has a new advanced syntax that lets you limit searches to particular
fields, use negated queries, look for exact matches, and navigate into
structured fields like `args` and `meta`.

Here are a few examples to show what's possible:

- `alpha in:worker` — only look within `worker` for "alpha"
- `alpha -omega in:tags,meta` — look for "alpha" and not "omega" within `tags`
  or `meta` fields
- `business in:args.account.plan` — dig into the account and plan maps within
  `args` to look for "business"
- `a1b2c3d4e5 in:meta.workflow_id` — look for an exact workflow id

See the new [searching guide][sg] for more examples.

[sg]: searching.html

### Push State Navigation

Navigation, filtering, and search now use push-state for navigation. This makes
it possible to deep-link into job details, save searches for later, or to share
filter combinations with co-workers.

## v2.6.2 — 2021-05-19

### Fixed

- Strictly guard against missing stats ETS table

  During a restart it was possible for the dashboard to receive a refresh signal
  before the stats plugin had finished mounting. This introduces a stricter set
  of conditionals that will safely degrade stats results back to an empty state
  when the ets table isn't available.

- Increase the timeout while waiting for config on dashboard mount. The restart
  period for some apps exceeds 5s and mounting would still cause an error.

## v2.6.1 — 2021-04-23

### Fixed

- Update stale sidebar state and queue counts when there aren't any jobs
  matching the given state or queue.

  When a queue/state combination had no values, the counts on the sidebar would
  "stick" and only show the previous non-zero value. This was most noticeable
  with the `executing` state as it worked through jobs quickly.

- Apply access controls on the server side as well as the client. It is no
  longer possible to use blocked actions by manually restoring button HTML in
  the browser.

## v2.6.0 — 2021-04-02

### Remove Reliance on Beats

Previously, node and queue information on the dashboard was powered by heartbeat
records stored in the `oban_beats` table. That is no longer the case and the
dashboard is entirely independent from beats and from Pro.

Check out the [Oban v2.6 upgrade guide](v2-6.html) for a walkthrough on using
the Gossip plugin for realtime updates.

### Content Security Policy

To secure the dashboard, or comply with an existing CSP within your application,
you can specify nonce keys for images, scripts and styles. For example, to pull
the asset nonce from a single `:my_csp_nonce` assignment:

```elixir
oban_dashboard("/oban", csp_nonce_assign_key: :my_csp_nonce)
```

See [the CSP install guide](web_installation.html#content-security-policy) for details.

### Changed

- Remove dependency on `oban_pro` (again). The dashboard is driven by events and
  data provided by Oban alone.

- Bump the Oban dependency `~> v2.6`

## v2.5.2 — 2021-03-04

### Changed

- Restore a dependency on `oban_pro`, as removal broke the install flow for many
  applications that had an implicit dependency.

- Bump the minimum `oban` version from v2.3 to v2.4 to enhance compatibility
  with `oban_pro`.

- Bump the minimum Elixir version from v1.8 to v1.9, matching recent `oban` and
  `oban_pro` releases.

## v2.5.1 — 2021-01-28

### Fixed

- Conditionally increase `max_attempts` when bulk retrying jobs. The check
  constraint added by Oban 2.4.0 exposed a bug which made it impossible to retry
  jobs that had exhausted all available attempts.

## v2.5.0 — 2021-01-15

### Web Resolver Behaviour

A new `Oban.Web.Resolver` behaviour module allows users to resolve the current
user when loading the dashboard, apply per-user access controls and set per-user
refresh rates.

    defmodule MyApp.Resolver do
      @behaviour Oban.Web.Resolver

      @impl true
      def resolve_user(conn) do
        conn.private.current_user
      end

      @impl true
      def resolve_access(user) do
        if user.admin? do
          [cancel_jobs: true, delete_jobs: true, retry_jobs: true]
        else
          :read_only
        end
      end

      @impl true
      def resolve_refresh(_user), do: 1
    end

Pass your `Resolver` callback to `oban_dashboard` in your router:

    scope "/" do
      pipe_through :browser

      oban_dashboard "/oban", resolver: MyApp.Resolver
    end

Viola, your dashboard now has per-user access controls! Now only admins can
cancel, retry or delete jobs while other users can still monitor running jobs
and check stats.

See the new [Customization](web_customizing.html) guide for more examples and a
rundown of available access controls.

### Telemetry Integration

The `Oban.Web.Telemetry` module adds events for instrumentation, logging, error
reporting and activity auditing.

Action events are emitted whenever a user performs a write operation with the
dashboard, e.g. pausing a queue, cancelling a job, etc. Web now ships with a log
handler that you can attach to get full dashboard audit logging. Add this call
at application start:

    Oban.Web.Telemetry.attach_default_logger(:info)

It will output structured JSON logs matching the format that Oban uses,
including the user that performed the action:

      {
        "action":"cancel_jobs",
        "duration":2544,
        "event":"action:stop",
        "job_ids":[290950],
        "oban_name":"Oban",
        "source":"oban_web",
        "user":1818
      }

See the new [Telemetry](web_telemetry.html) guide for event details!

### Other Improvements

- Remove a hard dependency on `oban_pro`. If you rely on any Pro plugins be sure
  to specify an `oban_pro` dependency in your `mix.exs`.

- Remove erroneous batch "Delete" action from states where it shouldn't apply,
  e.g. `executing`.

- Require confirmation before deleting jobs. Deleting is permanent and
  irreversible, unlike cancelling or other possible actions.

- Optimize the query that calculates queue and state counts in the sidebar. With
  millions of jobs the query could take longer than the refresh rate, leading to
  problems.

## v2.4.0 — 2020-12-11

### Added

- Allow `default_refresh` option when mounting a dashboard in a router.

  The refresh rate controls how frequently the server pulls statistics from the
  database, and when data is pushed from the server. The default refresh rate is
  1 second, but you can now customize it when mounting a dashboard.

  For example, to set the default refresh to 5 seconds:

  ```elixir
  scope "/" do
    pipe_through :browser

    oban_dashboard "/oban", default_refresh: 5
  end
  ```

  This makes it easy to reduce the load on your database when a lot of users are
  viewing Oban dashboards.

## v2.3.1 — 2020-11-27

### Changed

- Upgrade minimum Phoenix Live View dependency to `0.15`.

### Fixed

- Allow retrying or deleting cancelled jobs when they were never attempted.

## v2.3.0 — 2020-11-06

### Added

- Cancelling a job transitions the job to the `cancelled` state rather than
  `discarded`. The `discarded` state is now reserved for jobs that exhaust retry
  attempts or are purposefully discarded through a `{:discard, reason}` tuple.

- Display `meta` in the job details view.

### Changed

- Upgrade Oban dependency to `~> 2.3.0` to support the new `cancelled` state,
  and `meta` field.

## v2.2.3 — 2020-10-15

### Changed

- Replace the queue scale slider with a number input and a submit button. Aside
  from how difficult it was to scale accurately with a slider, it would fire
  erroneous `update` events due to DOM changes.

## v2.2.2 — 2020-10-11

### Changed

- Upgrade Oban dependency to `~> 2.2.0` along with fixes for the move to
  `Oban.Registry` and `Oban.Repo`.

## v2.2.1 — 2020-09-29

### Fixed

- Prevent layout jumb between initial render and subsequent mount. This was
  caused by the lack of a closing tag that was later injected on DOM update.

- Prevent bleeding events between nested components. The lack of a closing tag
  seemed to confuse event handling and allowed the wrong component to receive
  events.

- Correct touch event handling in the sidebar for mobile devices.

## v2.2.0 — 2020-09-11

### Added

- Support multiple isolated dashboards by providing an `oban_name` option to
  `oban_dashboard/2` calls in the Phoenix router.

  For example, to mount dashboards for multiple Oban instances in an umbrella:

      defmodule MyAppWeb.Router do
        use Phoenix.Router

        import Oban.Web.Router

        scope "/", MyAppWeb do
          pipe_through [:browser]

          oban_dashboard "/oban/web", oban_name: MyWeb.Oban
          oban_dashboard "/oban/ops", oban_name: MyOps.Oban
          oban_dashboard "/oban/ingestion", oban_name: MyIngestion.Oban
        end
      end

### Changed

- Clicking anywhere on a job row now opens the details view. Previously only
  clicking the rightmost "expand" icon opened details, and clicking on the
  worker name would search for other jobs with the same worker. Now the
  rightmost "document search" icon performs a related job search.

- Close the job details view when a user clicks a node name, job state, or queue
  name in the sidebar.

- Prevent ugly overflow issues when there are long node or queue names in the
  sidebar. Note that the full name is still visible on hover.

## v2.1.1 — 2020-08-24

### Fixed

- Correct expected plugin naming scheme for compatibility with Oban `>= 2.1`.

- Increase stats collection and activation timeouts to compensate for spikes in
  table size or additional load on the database pool from other processes.

## v2.1.0 — 2020-08-06

### Added

- Support alternate live socket transports, namely the "longpoll" transport.
  Users can specify either "websocket" or "longpoll" directly from the
  `oban_dashboard/2` call in their Phoenix router (which avoids global
  configuration).

### Fixed

- Skip full text search for PostgreSQL versions `< 11.0`. Older PG versions
  don't have proper support for JSONB vectorization or web style search
  operations.

## v2.0.0 — 2020-07-10

### Changed

- Upgrade to Oban `2.0.0`, LiveView `~> 0.14`, and add a dependency on Oban
  Pro `0.3.0`.

- Add simple load less/load more pagination for browsing through jobs

- Move details view inline, eliminating modal sizing and scrolling issues

- Display `queue_time` and `run_time` in the job details view

- Restore worker filtering using auto-populated search terms

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
