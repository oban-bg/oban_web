defmodule Oban.Web.Telemetry do
  @moduledoc false

  require Logger

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

  def action(name, socket, meta, fun) do
    meta =
      meta
      |> Map.new()
      |> Map.put(:action, name)
      |> Map.put(:user, socket.assigns.user)
      |> Map.put(:config, socket.assigns.conf)

    :telemetry.span([:oban_web, :action], meta, fn ->
      fun.()

      {:ok, meta}
    end)
  end

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

  defp inspect_user(%{id: id}), do: id
  defp inspect_user(_), do: nil

  defp inspect_config(%{name: oban_name}),
    do: oban_name |> to_string() |> String.trim_leading("Elixir.")

  defp inspect_config(_), do: "Oban"
end
