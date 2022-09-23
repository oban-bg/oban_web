# Telemetry

Oban Web uses `Telemetry` to provide instrumentation and to power logging
of dashboard activity. See the [Telemetry][tel] guide for a breakdown of emitted
events and how to use the default logger.

## Action Events

An action event is emitted whenever a user performs a write operation with the
dashboard, e.g. pausing a queue, cancelling a job, etc.

The dashboard emits the following events:

* `[:oban_web, :action, :start]`
* `[:oban_web, :action, :stop]`
* `[:oban_web, :action, :exception]`

Action events include the action name, Oban config, the user that performed the
action ([if available][cus]), and relevant metadata. In addition, failed actions
provide the error type, the error itself, and the stacktrace.

The following chart shows the _base metadata_ for each event:

| event        | measures       | metadata                                              |
| ------------ | ---------------| ----------------------------------------------------- |
| `:start`     | `:system_time` | `:action, :config, :user`                             |
| `:stop`      | `:duration`    | `:action, :config, :user`                             |
| `:exception` | `:duration`    | `:action, :config, :user, :kind, :error, :stacktrace` |

For `:exception` events the metadata includes details about what caused the
failure. The `:kind` value is determined by how an error occurred.

This chart breaks down the possible actions and their specific metadata:

| action          | metadata           |
| --------------- | ------------------ |
| `:pause_queue`  | `:queue`           |
| `:resume_queue` | `:queue`           |
| `:scale_queue`  | `:queue`, `:limit` |
| `:cancel_jobs`  | `:job_ids`         |
| `:delete_jobs`  | `:job_ids`         |
| `:retry_jobs`   | `:job_ids`         |

## Action Logging

The `Oban.Web.Telemetry` module ships with a default handler that logs
structured JSON for `:stop` and `:exception` events. To attach the logger, call
`attach_default_logger/1` as your application starts:

```elixir
def start(_type, _args) do
  children = [
    MyApp.Repo,
    MyApp.Endpoint,
    {Oban, oban_opts()}
  ]

  Oban.Telemetry.attach_default_logger(level: :info)
  Oban.Web.Telemetry.attach_default_logger(level: :info)

  Supervisor.start_link(children, [strategy: :one_for_one, name: MyApp.Supervisor])
end
```

Here is an example of the JSON output for an `action:stop` event:

```json
{
  "action":"cancel_jobs",
  "duration":2544,
  "event":"action:stop",
  "job_ids":[290950],
  "oban_name":"Oban",
  "source":"oban_web",
  "user":1818
}
```

There is also an `encoded` option if you'd prefer structured logging without
automatic JSON encoding:

```elixir
Oban.Telemetry.attach_default_logger(encoded: false, level: :info)
Oban.Web.Telemetry.attach_default_logger(encoded: false, level: :info)
```

## Log Metadata

Event metadata is passed through directly along with these constant fields:

* `duration` — Action duration, recorded in native units and logged as
  microseconds
* `source` — Always "oban_web", which is useful for log filtering
* `user` — If the dashboard was mounted with a [resolver][cus] that implements
  `resolve_user/1` this is the user's id, otherwise `null`
* `oban_name` — The instance that the dashboard is linked to, typically this is
  "Oban" unless an application is using multiple Oban instances.

[cus]: web_customizing.html
