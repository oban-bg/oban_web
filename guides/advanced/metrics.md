# Metrics

Web's realtime updates, counts, and charts are powered by the [Oban.Met][met] package. `Met`
provides core monitoring and introspection functionality from a single automatically managed
supervisor.

* Telemetry powered metric tracking and aggregation with compaction
* Periodic queue checking and reporting (replaces the `Gossip` plugin)
* Periodic counting and reporting with backoff (replaces `Stats` plugin)
* Leader backed distributed metric sharing with handoff between nodes

[met]: https://github.com/oban-bg/oban_met

## Usage in Worker Only Nodes

To receive metrics from non-web nodes in a system with separate "web" and "worker" applications
you must explicitly include `oban_met` as a dependency for "workers".

```elixir
{:oban_met, "~> 1.0"},
```

## Auto Start

Supervised `Met` instances start automatically along with Oban instances unless Oban is in
testing mode. You can disable auto-starting globally with application configuration:

```elixir
config :oban_met, auto_start: false
```

However, note that a running `Met` instance is required for the Web dashboard to load and without
one the dashboard won't function.
