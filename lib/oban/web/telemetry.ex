defmodule Oban.Web.Telemetry do
  @moduledoc false

  require Logger

  def attach_default_logger(level \\ :info) do
    events = [
      [:oban_web, :action, :stop],
      [:oban_web, :action, :exception]
    ]

    :telemetry.attach_many("oban_web-logger", events, &handle_event/4, level)
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

  def handle_event([:oban_web, :action, event], measure, meta, level) do
    Logger.log(level, fn ->
      {conf, meta} = Map.pop(meta, :conf)
      {user, meta} = Map.pop(meta, :user)

      meta
      |> Map.take([:queue, :limit, :job_ids, :kind])
      |> Map.put(:user, inspect_user(user))
      |> Map.put(:oban_name, inspect_config(conf))
      |> Map.put(:duration, System.convert_time_unit(measure.duration, :native, :microsecond))
      |> Map.put(:event, "action:#{event}")
      |> Map.put(:source, "oban_web")
      |> Jason.encode_to_iodata!()
    end)
  end

  defp inspect_user(%{id: id}), do: id
  defp inspect_user(_), do: nil

  defp inspect_config(%{name: oban_name}),
    do: oban_name |> to_string() |> String.trim_leading("Elixir.")

  defp inspect_config(_), do: "Oban"
end
