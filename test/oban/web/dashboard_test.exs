defmodule Oban.Web.DashboardTest do
  use Oban.Web.Case, async: true

  test "forbidding mount using a resolver callback" do
    assert {:error, {:redirect, redirect}} = live(build_conn(), "/oban-limited")
    assert %{to: "/", flash: %{"error" => "Access forbidden"}} = redirect
  end

  test "waiting for oban config while mounting during a restart" do
    opts = prepare_oban_opts()

    # Start the instance after the mount begins, and keep it alive until the mount finishes.
    task =
      Task.async(fn ->
        Process.sleep(25)

        {:ok, _pid} = Oban.start_link(opts)

        receive do
          :mounted -> :ok
        after
          1_000 -> :error
        end
      end)

    assert {:ok, _live, _html} = live(build_conn(), "/oban")

    send(task.pid, :mounted)

    assert :ok = Task.await(task)
  end

  describe "refresh" do
    test "toggling refresh off and back on with the shortcut" do
      start_supervised_oban!()

      {:ok, live, _html} = live(build_conn(), "/oban")

      assert %{refresh: 1, timer: timer} = assigns(live)
      assert is_reference(timer)

      live
      |> with_target("#refresh-selector")
      |> render_hook("toggle-refresh", %{})

      assert %{refresh: -1, original_refresh: 1, timer: nil} = assigns(live)
      assert has_element?(live, "#refresh-menu-toggle", "Off")

      live
      |> with_target("#refresh-selector")
      |> render_hook("toggle-refresh", %{})

      assert %{refresh: 1, original_refresh: nil, timer: timer} = assigns(live)
      assert is_reference(timer)
      assert has_element?(live, "#refresh-menu-toggle", "1s")
    end

    defp assigns(live) do
      # Toggling routes through a message to the view, so the state is settled after a render.
      render(live)

      :sys.get_state(live.pid).socket.assigns
    end
  end

  describe "isolation" do
    test "viewing available jobs for an instance with a custom prefix" do
      oban = start_supervised_oban!(prefix: "private")

      {:ok, live, _html} = live(build_conn(), "/oban")

      job_1 = Job.new(%{}, worker: AlphaWorker)
      job_2 = Job.new(%{}, worker: DeltaWorker)
      job_3 = Job.new(%{}, worker: GammaWorker)

      Oban.insert_all(oban, [job_1, job_2, job_3])

      html = click_state(live, "available")

      assert html =~ "AlphaWorker"
      assert html =~ "DeltaWorker"
      assert html =~ "GammaWorker"
    end

    test "routing to the configured path for a mount point" do
      start_supervised_oban!()

      assert {:error, {:live_redirect, %{to: "/oban-private/queues"}}} =
               live(build_conn(), "/oban-private/queues/omicron")
    end

    test "switching between actively running instances" do
      oban_1 = start_supervised_oban!()
      oban_2 = start_supervised_oban!()

      {:ok, live, _html} = live(build_conn(), "/oban")

      assert has_element?(live, instance_option(oban_1))
      assert has_element?(live, instance_option(oban_2))

      change_instance(live, oban_2)

      assert has_element?(live, "#instance-select-menu-toggle", inspect(oban_2))
    end

    test "disallowing switching to unresolved instances" do
      oban_1 = start_supervised_oban!()
      oban_2 = start_supervised_oban!()

      {:ok, live, _html} = live(build_conn(), "/oban-private")

      refute has_element?(live, instance_option(oban_2))
      refute has_element?(live, "#instance-select-menu-toggle")
      assert has_element?(live, "#instance-select", inspect(oban_1))
    end

    test "defaulting to the first allowed running instance" do
      oban_1 = start_supervised_oban!()
      _oban_2 = start_supervised_oban!()

      {:ok, live, _html} = live(build_conn(), "/oban-private")

      assert has_element?(live, "#instance-select", inspect(oban_1))
    end

    test "restoring a stashed instance the resolver allows" do
      _oban_1 = start_supervised_oban!()
      oban_2 = start_supervised_oban!()

      {:ok, live, _html} = live(stash_instance(build_conn(), oban_2), "/oban")

      assert has_element?(live, "#instance-select-menu-toggle", inspect(oban_2))
    end

    test "ignoring a stashed instance the resolver doesn't allow" do
      oban_1 = start_supervised_oban!()
      oban_2 = start_supervised_oban!()

      {:ok, live, _html} = live(stash_instance(build_conn(), oban_2), "/oban-private")

      assert has_element?(live, "#instance-select", inspect(oban_1))
    end
  end

  defp click_state(live, state) do
    live
    |> element("#sidebar #states #filter-#{state}")
    |> render_click()

    render(live)
  end

  defp change_instance(live, oban) do
    live
    |> element("#instance-select button[role=menuitemradio]", inspect(oban))
    |> render_click()
  end

  defp instance_option(oban) do
    ~s(#instance-select button[phx-value-name="#{inspect(oban)}"])
  end

  # The browser restores the last selected instance through connect params.
  defp stash_instance(conn, oban) do
    put_connect_params(conn, %{"init_state" => %{"oban:instance" => inspect(oban)}})
  end
end
