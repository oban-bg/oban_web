defmodule Oban.Web.NewJob.FormComponentTest do
  use Oban.Web.Case, async: true

  import Phoenix.LiveViewTest

  alias Oban.Web.NewJob.FormComponent, as: Component

  setup do
    Process.put(:routing, :nowhere)
    :ok
  end

  describe "access control" do
    test "disables submit button for read_only access" do
      html = render_component(Component, base_assigns(access: :read_only), router: Router)

      assert html =~ "disabled"
      assert html =~ "Enqueue Job"
    end

    test "enables submit button for full access" do
      html = render_component(Component, base_assigns(access: :all), router: Router)

      assert html =~ "Enqueue Job"
      # Check that the submit button doesn't have a disabled attribute (not Tailwind classes)
      refute html =~ ~r/<button[^>]*type="submit"[^>]*disabled[=\s>]/
    end
  end

  describe "form rendering" do
    test "renders worker input" do
      html = render_component(Component, base_assigns(), router: Router)

      assert html =~ "Worker"
      assert html =~ ~s(id="worker")
    end

    test "renders args textarea" do
      html = render_component(Component, base_assigns(), router: Router)

      assert html =~ "Args (JSON)"
      assert html =~ ~s(id="args")
    end

    test "renders queue select" do
      html = render_component(Component, base_assigns(), router: Router)

      assert html =~ "Queue"
      assert html =~ ~s(id="queue")
    end

    test "hides advanced options by default" do
      html = render_component(Component, base_assigns(), router: Router)

      refute html =~ ~s(id="priority")
      refute html =~ ~s(id="tags")
      refute html =~ ~s(id="schedule_in")
      refute html =~ ~s(id="meta")
      refute html =~ ~s(id="max_attempts")
    end
  end

  describe "error display" do
    test "shows worker error when present" do
      assigns = base_assigns()
      assigns = Keyword.put(assigns, :errors, %{worker: "Worker is required"})

      html = render_component(Component, assigns, router: Router)

      assert html =~ "Worker is required"
    end

    test "shows args error when present" do
      assigns = base_assigns()
      assigns = Keyword.put(assigns, :errors, %{args: "Invalid JSON"})

      html = render_component(Component, assigns, router: Router)

      assert html =~ "Invalid JSON"
    end
  end

  defp base_assigns(opts \\ []) do
    conf = %Oban.Config{repo: Oban.Web.Repo}

    [
      id: "form",
      conf: conf,
      access: Keyword.get(opts, :access, :all),
      user: nil,
      queues: ["default"],
      workers: [],
      inputs: %{
        worker: "",
        args: "{}",
        queue: "default",
        priority: 0,
        tags: "",
        schedule_in: "",
        meta: "{}",
        max_attempts: 20,
        advanced: false
      },
      errors: %{}
    ]
    |> Keyword.merge(opts)
  end
end
