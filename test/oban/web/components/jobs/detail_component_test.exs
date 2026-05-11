defmodule Oban.Web.Jobs.DetailComponentTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  alias Oban.Web.Jobs.DetailComponent, as: Component

  defmodule CustomResolver do
    @behaviour Oban.Web.Resolver

    @impl Oban.Web.Resolver
    def format_job_args(_job), do: "ARGS REDACTED"
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

  # Helpers

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
