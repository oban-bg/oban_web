defmodule Oban.Web.Telemetry do
  @moduledoc """
  Oban Web uses `Telemetry` to provide instrumentation and to power logging of dashboard activity.

  ## Action Events

  An action event is emitted whenever a user performs a write operation with the dashboard, e.g.
  pausing a queue, cancelling a job, etc.

  The dashboard emits the following events:

  * `[:oban_web, :action, :start]`
  * `[:oban_web, :action, :stop]`
  * `[:oban_web, :action, :exception]`

  Action events include the action name, Oban config, the user that performed the action (if
  available), and relevant metadata. In addition, failed actions provide the error type, the error
  itself, and the stacktrace.

  The following chart shows the _base metadata_ for each event:

  | event        | measures       | metadata                                              |
  | ------------ | ---------------| ----------------------------------------------------- |
  | `:start`     | `:system_time` | `:action, :config, :user`                             |
  | `:stop`      | `:duration`    | `:action, :config, :user`                             |
  | `:exception` | `:duration`    | `:action, :config, :user, :kind, :error, :stacktrace` |

  For `:exception` events the metadata includes details about what caused the failure. The `:kind`
  value is determined by how an error occurred.

  This chart breaks down the possible actions and their specific metadata:

  | action               | metadata           |
  | -------------------- | ------------------ |
  | `:mount`             |                    |
  | `:pause_queue`       | `:queue`           |
  | `:resume_queue`      | `:queue`           |
  | `:pause_all_queues`  |                    |
  | `:resume_all_queues` |                    |
  | `:scale_queue`       | `:queue`, `:limit` |
  | `:cancel_jobs`       | `:job_ids`         |
  | `:delete_jobs`       | `:job_ids`         |
  | `:retry_jobs`        | `:job_ids`         |

  ## Action Logging

  The `Oban.Web.Telemetry` module ships with a default handler that logs structured JSON for
  `:stop` and `:exception` events. To attach the logger, call `attach_default_logger/1` as your
  application starts:

  ```elixir
  def start(_type, _args) do
    children = [
      MyApp.Repo,
      MyApp.Endpoint,
      {Oban, oban_opts()}
    ]

    Oban.Telemetry.attach_default_logger(:info)
    Oban.Web.Telemetry.attach_default_logger(:info)

    Supervisor.start_link(children, [strategy: :one_for_one, name: MyApp.Supervisor])
  end
  ```
  """

  require Logger

  @doc """
  Attaches a structured telemetry handler for logging.

  ## Options

  * `:level` — The log level to use for logging output, defaults to `:info`

  * `:encode` — Whether to encode log output as JSON, defaults to `true`

  ## Events

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

  Event metadata is passed through directly along with these constant fields:

  * `action` — The reported action, e.g. `cancel_jobs`

  * `duration` — Action duration, recorded in native units and logged as microseconds

  * `source` — Always "oban_web", which is useful for log filtering

  * `user` — If the dashboard was mounted with an `Oban.Web.Resolver` that implements
    `resolve_user/1` this is the user's id, otherwise `null`

  * `oban_name` — The instance that the dashboard is linked to, typically this is
    "Oban" unless an application is using multiple Oban instances.

  ## Examples

  Attach the logger at the `:debug` log level:

      Oban.Web.Telemetry.attach_default_logger(level: :debug)

  Disable JSON encoding output:

      Oban.Web.Telemetry.attach_default_logger(encode: false)
  """
  def attach_default_logger(opts \\ [encode: true, level: :info])

  def attach_default_logger(level) when is_atom(level) do
    attach_default_logger(level: level)
  end

  def attach_default_logger(opts) when is_list(opts) do
    events = [
      [:oban_web, :action, :stop],
      [:oban_web, :action, :exception]
    ]

    opts =
      opts
      |> Keyword.put_new(:encode, true)
      |> Keyword.put_new(:level, :info)

    :telemetry.attach_many("oban_web-logger", events, &__MODULE__.handle_event/4, opts)
  end

  @doc false
  def action(name, socket, meta, fun) do
    meta =
      meta
      |> Map.new()
      |> Map.put(:action, name)
      |> Map.put(:user, socket.assigns.user)
      |> Map.put(:config, socket.assigns.conf)

    :telemetry.span([:oban_web, :action], meta, fn -> {fun.(), meta} end)
  end

  @doc false
  def handle_event([:oban_web, :action, event], measure, meta, opts) do
    level = Keyword.fetch!(opts, :level)

    Logger.log(level, fn ->
      {conf, meta} = Map.pop(meta, :conf)
      {user, meta} = Map.pop(meta, :user)

      output =
        meta
        |> Map.take([:queue, :limit, :job_ids, :kind])
        |> Map.put(:user, inspect_user(user))
        |> Map.put(:oban_name, inspect_config(conf))
        |> Map.put(:duration, System.convert_time_unit(measure.duration, :native, :microsecond))
        |> Map.put(:event, "action:#{event}")
        |> Map.put(:source, "oban_web")

      if Keyword.fetch!(opts, :encode) do
        Jason.encode_to_iodata!(output)
      else
        output
      end
    end)
  end

  defp inspect_config(%{name: oban_name}), do: inspect(oban_name)
  defp inspect_config(_), do: "Oban"

  defp inspect_user(%{id: id}), do: id
  defp inspect_user(_), do: nil
end
