# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

Three confirmed primary audiences, all technical:

- **Elixir developers debugging failures** — investigating failed and retryable jobs, often under incident pressure. Speed to the offending job, its args, and its error history is the job to be done.
- **Ops/on-call engineers doing routine monitoring** — watching throughput, queue health, and node status day-to-day via the realtime charts and sidebar counts.
- **Admins managing queues** — scaling, pausing, resuming, and stopping queues across all running nodes; editing Pro-only controls (global limits, rate limiting, partitioning) where available.

Read-only access exists (access control restricts non-admins to viewing), but read-only stakeholders are not a design-driving audience.

## Product Purpose

Oban Web is a dashboard for the Oban job orchestration framework, hosted directly inside the user's own Phoenix application. Powered by Oban Met and Phoenix LiveView, it provides a distributed, lightweight, fully realtime view of background job activity: inspecting and acting on jobs, controlling queues, monitoring crons, and visualizing Pro workflows. Success means an engineer can find, understand, and resolve a job or queue problem faster than they could at a psql prompt.

## Positioning

**Embedded + realtime with zero infrastructure.** The dashboard mounts directly in the application it monitors — no external services, agents, or hosted components — and is fully realtime via a custom distributed time-series store (Oban Met) over LiveView. A hosted APM or third-party dashboard cannot truthfully claim this.

## Operating Context

- Mounted at a route in the host Phoenix app's router; multiple Oban instances switchable from a single mount point.
- Also distributed as a standalone Docker image (`ghcr.io/oban-bg/oban-dash`) for monitoring without embedding.
- Four pages: Jobs (filtering, inspection, batch actions), Queues (cross-node controls), Crons, and Workflows (Pro).
- Live updates with configurable refresh rates and automatic pausing on blur; used during incidents and for ambient monitoring alike.
- Dashboard actions emit telemetry for audit logging.
- Dev environment: `iex -S mix dev` runs a single-file server generating fake jobs; optional Python workers (`mix py.dev`) add cross-language job variety.

## Capabilities and Constraints

Confirmed binding constraints for all future design work:

- **Self-contained assets.** No CDN, external fonts, or external scripts — everything ships in the package and must work air-gapped.
- **Host-app isolation.** CSS/JS must not leak into or inherit from the host Phoenix application it's mounted in.
- **Dark/light theme parity.** Every surface must work in dark, light, and system-preference modes.
- **Realtime performance budget.** UI must stay light under frequent LiveView updates — no heavy JS frameworks or expensive re-renders.
- **Desktop-first, deliberately.** The dashboard is used at a desk on full-size screens. Mobile usage is not important and smaller screens (tablets included) are not an optimization target; layouts should not compromise desktop density or clarity for responsive coverage.

Other product facts: Oban Pro is an optional integration that unlocks additional queue controls and the Workflows page; the UI must degrade gracefully without it. Feature parity concerns span PostgreSQL, MySQL, and SQLite backends.

## Brand Commitments

- Part of the Oban family (Oban, Oban Pro, Oban Met), maintained by the Oban team; the Oban Web logo lives at `assets/oban-web-logo.svg`.
- An established visual identity already ships in production (Tailwind-based, dark/light themed). Init records its existence without documenting it; `/impeccable document` owns that.

## Evidence on Hand

- Production screenshots: `assets/oban-web-preview-light.png`, `assets/oban-web-preview-dark.png`.
- Published docs at hexdocs.pm/oban_web with installation, standalone, and advanced guides (`guides/`).
- A realistic runnable demo via the dev server and Python workers — no need to fabricate data for design work.

## Product Principles

1. **The database is the truth; the dashboard is the fastest lens on it.** Never show derived state that could disagree with what an engineer would find by querying directly.
2. **Realtime is the product.** Freshness, live counts, and low-latency updates outrank visual flourish; nothing may make the live feed feel heavier.
3. **Guest in someone else's house.** The dashboard lives inside users' own applications — it must be self-contained, isolated, and unobtrusive to host.
4. **Operate under pressure.** Design for the 2 a.m. incident: scanability, keyboard shortcuts, and unambiguous state labels before decoration.
5. **Pro deepens, never gates the basics.** Core monitoring and job actions work everywhere; Pro features appear as natural extensions, not upsells.
