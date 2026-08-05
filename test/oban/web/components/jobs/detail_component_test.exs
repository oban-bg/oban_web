defmodule Oban.Web.Jobs.DetailComponentTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  alias Oban.Web.Jobs.DetailComponent, as: Component

  defmodule CustomResolver do
    @behaviour Oban.Web.Resolver

    @impl Oban.Web.Resolver
    def format_job_args(_job), do: "ARGS REDACTED"

    @impl Oban.Web.Resolver
    def format_recorded(_recorded, _job), do: "RECORDED REDACTED"

    @impl Oban.Web.Resolver
    def recorded_size_limit, do: :infinity
  end

  setup do
    Process.put(:routing, :nowhere)

    :ok
  end

  test "restricting action buttons based on job state" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, state: "retryable"}

    html = render_component(Component, assigns(job), router: Router)
    # Retryable jobs can be cancelled
    assert html =~ ~s(phx-click="cancel")
    refute html =~ ~s(id="detail-cancel" type="button" disabled)

    # Available job can be cancelled
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, state: "available"}
    html = render_component(Component, assigns(job), router: Router)
    assert html =~ ~s(phx-click="cancel")
    refute html =~ ~s(id="detail-cancel" type="button" disabled)
  end

  test "disabling actions based on job state" do
    now = DateTime.utc_now()
    scheduled_at = DateTime.add(now, -60, :second)

    job = %Oban.Job{
      id: 1,
      worker: "MyApp.Worker",
      args: %{},
      state: "executing",
      attempted_at: now,
      inserted_at: scheduled_at,
      scheduled_at: scheduled_at
    }

    html = render_component(Component, assigns(job), router: Router)

    # Executing jobs can be cancelled (not disabled)
    assert html =~ ~s(phx-click="cancel")
    refute html =~ ~s(id="detail-cancel" type="button" disabled)

    # Executing jobs cannot be deleted (button is disabled)
    assert html =~ ~s(id="detail-delete" type="button" disabled)
  end

  test "customizing args formatting with a resolver" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{"secret" => "sauce"}}

    html = render_component(Component, assigns(job, resolver: CustomResolver), router: Router)

    assert html =~ "ARGS REDACTED"
  end

  test "displaying the diagnostic PID" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, state: "executing"}

    diagnostics = %{
      "node" => "worker@host",
      "pid" => "#PID<0.1.0>",
      "info" => %{
        "status" => "waiting",
        "memory" => 1_024,
        "message_queue_len" => 0,
        "reductions" => 10,
        "heap_size" => 20,
        "stack_size" => 30,
        "current_stacktrace" => nil
      }
    }

    html =
      render_component(Component, assigns(job, diagnostics: diagnostics, diagnostics_at: 0),
        router: Router
      )

    assert html =~ "worker@host"
    assert html =~ "#PID&lt;0.1.0&gt;"
    refute html =~ ~s(id="copy-pid")
  end

  describe "awaitable signals" do
    test "rendering the received signal section with a decoded payload" do
      encoded = encode_term(%{decision: "approved"})

      job = %Oban.Job{
        id: 1,
        worker: "MyApp.Worker",
        args: %{},
        meta: %{"signal" => encoded}
      }

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "icon-signal"
      assert html =~ "Received Signal"
      assert html =~ ~s|decision: &quot;approved&quot;|
      assert html =~ ~s(id="copy-signal")
      refute html =~ encoded
    end

    test "rendering the awaiting state with a deadline" do
      wait_until = System.system_time(:millisecond) + :timer.minutes(30)

      job = %Oban.Job{
        id: 1,
        worker: "MyApp.Worker",
        args: %{},
        meta: %{"wait_until" => wait_until}
      }

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "icon-signal"
      assert html =~ "Awaiting Signal"
      assert html =~ "Deadline"
      assert html =~ ~s(id="copy-signal" class)
      assert html =~ "invisible"
    end

    test "rendering the awaiting state with no deadline" do
      job = %Oban.Job{
        id: 1,
        worker: "MyApp.Worker",
        args: %{},
        meta: %{"wait_until" => "infinity"}
      }

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "Awaiting Signal"
      assert html =~ "No deadline"
    end

    test "hiding the encoded signal from the raw meta dump" do
      encoded = encode_term(%{secret: "value"})
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: %{"signal" => encoded}}

      html = render_component(Component, assigns(job), router: Router)

      refute html =~ encoded
    end

    test "omitting the section entirely when no signal is present" do
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}}

      html = render_component(Component, assigns(job), router: Router)

      refute html =~ "icon-signal"
      refute html =~ "Received Signal"
      refute html =~ "Awaiting Signal"
    end
  end

  describe "recorded output" do
    test "rendering inline output with a decoded payload" do
      encoded = encode_term(%{total: 42})
      job = recorded_job(%{"return" => encoded})

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "Recorded Output"
      assert html =~ "total: 42"
      assert html =~ ~s(id="copy-recorded")
      refute html =~ encoded
    end

    test "reporting a recorded job that hasn't stored output yet" do
      job = recorded_job(%{})

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "No Recording Yet"
      refute html =~ ~s(id="copy-recorded")
      refute html =~ ~s(id="load-recorded")
    end

    test "omitting the section entirely without recording enabled" do
      job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}}

      html = render_component(Component, assigns(job), router: Router)

      refute html =~ "Recorded Output"
    end

    test "customizing recorded formatting with a resolver" do
      job = recorded_job(%{"return" => encode_term(%{secret: "sauce"})})

      html = render_component(Component, assigns(job, resolver: CustomResolver), router: Router)

      assert html =~ "RECORDED REDACTED"
      refute html =~ "sauce"
    end

    test "offering an explicit load button for externally stored output" do
      job = recorded_job(%{"return" => key(), "storage" => "encoded", "size" => 2048})

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "Stored externally"
      assert html =~ ~s(id="load-recorded")
      assert html =~ "Load Output"
      assert html =~ "2.0 KB"
      refute html =~ ~s(id="copy-recorded")
    end

    test "refusing to render output larger than the resolver's limit" do
      job = recorded_job(%{"return" => key(), "storage" => "encoded", "size" => 5_000_000})

      html = render_component(Component, assigns(job), router: Router)

      assert html =~ "Output is too large to display"
      refute html =~ ~s(id="load-recorded")

      html = render_component(Component, assigns(job, resolver: CustomResolver), router: Router)

      assert html =~ ~s(id="load-recorded")
    end

    test "raising when the resolver can't decode the payload" do
      job = recorded_job(%{"return" => "not-a-base64-term"})

      assert_raise ArgumentError, fn ->
        render_component(Component, assigns(job), router: Router)
      end
    end

    test "hiding recording internals from the raw meta dump" do
      encoded = encode_term(%{secret: "value"})

      job =
        recorded_job(%{
          "return" => encoded,
          "storage" => "encoded-bucket-config",
          "size" => 128,
          "safe_decode" => true
        })

      html = render_component(Component, assigns(job), router: Router)

      refute html =~ encoded
      refute html =~ "encoded-bucket-config"
      refute html =~ "safe_decode"
    end
  end

  # Helpers

  defp recorded_job(meta) do
    meta = Map.put(meta, "recorded", true)

    %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, meta: meta}
  end

  defp key, do: Ecto.UUID.generate()

  defp assigns(job, opts \\ []) do
    os_time = System.system_time(:second)

    [
      access: :all,
      diagnostics: nil,
      diagnostics_at: nil,
      history: [],
      id: :details,
      os_time: os_time,
      params: %{},
      resolver: nil
    ]
    |> Keyword.put(:job, job)
    |> Keyword.merge(opts)
  end
end
