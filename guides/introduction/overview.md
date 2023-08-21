# Overview

🧭 Oban.Web is a view of Oban's inner workings that you host directly within your Phoenix
application. Powered by Oban Metrics and Phoenix Live View, it is distributed, lightweight, and
fully realtime.

Get started with [installation](installation.html).

## Features

### 📊 Realtime Charts

Powered by a custom, distrubted time-series data store that's compacted for hours of efficient
storage and filterable by node, queue, state, and worker.

### 🛸 Live Inspection

Monitor background job activity across all of your nodes in real time.

### 🔬 Detailed Inspection

View job details including when, where and how it was ran (or how it failed to run).

### 🔄 Batch Actions

Cancel, delete and retry selected jobs or all jobs matching the current filters.

### 🎛️ Queue Controls

Scale, pause, resume and stop queues across all running nodes with a couple of clicks.

## Learn More

### [🔍 Powerful Filtering](filtering.html)

Intelligently filter jobs, with auto-completed suggestions across all fields.

### [♊ Multiple Dashboards](Oban.Web.Router.html)

Mount multiple dashboards with isolated controls and configure exotic connections.

### [🔒 Access Control](Oban.Web.Resolver.html)

Allow admins to control queues and interract with jobs while restricting other users to read-only
use of the dashboard.

### [🎬 Action Logging](Oban.Web.Telemetry.html)

Use telemetry events to instrument and report all of a user's dashboard activity.
