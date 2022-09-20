defmodule Oban.Web.TelemetryTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Oban.Web.Telemetry

  @events [
    [:oban_web, :action, :stop],
    [:oban_web, :action, :exception]
  ]

  @socket %{assigns: %{conf: %{name: Oban}, user: %{id: 1}}}

  describe "action/4" do
    test "decorating provided metadata with the action and user" do
      handle_event = fn event, _measure, meta, pid ->
        send(pid, {event, meta})
      end

      :telemetry.attach_many("web-test", @events, handle_event, self())

      assert :ok = Telemetry.action(:pause_queue, @socket, [queue: "alpha"], fn -> :ok end)

      assert_receive {[:oban_web, :action, :stop], %{action: :pause_queue, user: %{id: 1}}}
    after
      :telemetry.detach("web-test")
    end
  end

  describe "attach_default_logger/1" do
    test "logging metadata with measurements" do
      :ok = Telemetry.attach_default_logger(:warn)

      logged =
        capture_log(fn ->
          Telemetry.action(:pause_queue, @socket, [queue: "alpha"], fn -> :ok end)

          Logger.flush()
        end)

      assert logged =~ ~s("source":"oban_web")
      assert logged =~ ~s("event":"action:stop")
      assert logged =~ ~s("queue":"alpha")
      assert logged =~ ~r|"duration":\d{1,5}|
      assert logged =~ ~r|"oban_name":"Oban"|
      assert logged =~ ~r|"user":1|
    after
      :telemetry.detach("oban_web-logger")
    end

    test "disabling encoding on the default logger" do
      :ok = Telemetry.attach_default_logger(encode: false, level: :warn)

      logged =
        capture_log(fn ->
          Telemetry.action(:pause_queue, @socket, [queue: "alpha"], fn -> :ok end)

          Logger.flush()
        end)

      assert logged =~ ~s(source: "oban_web")
      assert logged =~ ~s(event: "action:stop")
    after
        :telemetry.detach("oban_web-logger")
    end

    test "logging exceptions safely" do
      :ok = Telemetry.attach_default_logger(:warn)

      logged =
        capture_log(fn ->
          try do
            Telemetry.action(:pause_queue, @socket, [], fn -> raise "boom" end)
          rescue
            _exception ->
              :ok
          end

          Logger.flush()
        end)

      assert logged =~ ~s("source":"oban_web")
      assert logged =~ ~s("event":"action:exception")
      assert logged =~ ~s("kind":"error")
    after
      :telemetry.detach("oban_web-logger")
    end
  end
end
