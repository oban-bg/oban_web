defmodule Oban.Web.Jobs.DetailComponentTest do
  use Oban.Web.DataCase, async: true

  import Phoenix.LiveViewTest

  alias Oban.Web.Jobs.DetailComponent, as: Component

  defmodule CustomResolver do
    @behaviour Oban.Web.Resolver

    @impl Oban.Web.Resolver
    def format_job_args(_job), do: "ARGS REDACTED"
  end

  test "restricting action buttons based on access" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, state: "retryable"}

    html = render_component(Component, access: :read_only, id: job.id, job: job, resolver: nil)
    refute html =~ ~s(phx-click="cancel")

    html = render_component(Component, access: :all, id: job.id, job: job, resolver: nil)
    assert html =~ ~s(phx-click="cancel")
  end

  test "restricting actions based on job state" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, state: "executing"}

    html = render_component(Component, access: :all, id: job.id, job: job, resolver: nil)

    assert html =~ ~s(phx-click="cancel")
    refute html =~ ~s(phx-click="delete")
  end

  test "customizing args formatting with a resolver" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{"secret" => "sauce"}}

    html =
      render_component(
        Component,
        access: :read_only,
        id: job.id,
        job: job,
        resolver: CustomResolver
      )

    assert html =~ "ARGS REDACTED"
  end
end
