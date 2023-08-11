# Overview

[🧭 Oban.Web][gpr] is a view of Oban's inner workings that you host directly within your Phoenix
application. Powered by Phoenix Live View, it is extremely lightweight and fully realtime. It
builds on features provided by [Oban.Pro][pro] and is available [through a paid license][pri].

Get started with [installation](installation.html).

[gpr]: https://getoban.pro
[pri]: https://getoban.pro/pricing
[pro]: https://getoban.pro/docs/pro

## Features

**Live Inspection**—Monitor background job activity across all of your nodes
in real time.

**Composable Filtering**—Sift through jobs instantly with any combination of
queue, state, node, worker and other metadata.

**Detailed Inspection**—View job details including when, where and how it was
ran (or how it failed to run).

**Batch Actions**—Cancel, delete and retry selected jobs or all jobs matching
the current filters.

**Queue Controls**—Scale, pause, resume and stop queues across all running nodes
with a couple of clicks.

## Advanced Usage

[**Powerful Search**](searching.html) — Intelligently search through job arguments
instantly, with support for partial matches and auto-correction.

[**Access Control**](customizing.html)—Allow admins to control queues and
interract with jobs while restricting other users to read-only use of the
dashboard.

[**Action Logging**](telemetry.html)—Use telemetry events to instrument and
report all of a user's dashboard activity.
