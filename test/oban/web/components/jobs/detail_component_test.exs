defmodule Oban.Web.Jobs.DetailComponentTest do
  use Oban.Web.DataCase, async: true

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

  test "restricting action buttons based on access" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, state: "retryable"}

    html = render_component(Component, assigns(job, access: :read_only), router: Router)
    refute html =~ ~s(phx-click="cancel")

    html = render_component(Component, assigns(job, access: :all), router: Router)
    assert html =~ ~s(phx-click="cancel")
  end

  test "restricting actions based on job state" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{}, state: "executing"}

    html = render_component(Component, assigns(job), router: Router)

    assert html =~ ~s(phx-click="cancel")
    refute html =~ ~s(phx-click="delete")
  end

  test "customizing args formatting with a resolver" do
    job = %Oban.Job{id: 1, worker: "MyApp.Worker", args: %{"secret" => "sauce"}}

    html = render_component(Component, assigns(job, resolver: CustomResolver), router: Router)

    assert html =~ "ARGS REDACTED"
  end

  defp assigns(job, opts \\ []) do
    [access: :all, id: :details, resolver: nil, params: %{}]
    |> Keyword.put(:job, job)
    |> Keyword.merge(opts)
  end
end
