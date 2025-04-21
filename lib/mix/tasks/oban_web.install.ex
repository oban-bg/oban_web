defmodule Mix.Tasks.ObanWeb.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs Oban Web into your Phoenix application"
  end

  def example do
    "mix oban_web.install"
  end

  def long_doc do
    """
    #{short_doc()}

    This task configures your Phoenix application to use the Oban Web dashboard:

    * Adds the required `Oban.Web.Router` import
    * Sets up the dashboard route at "/oban" within the :dev_routes conditional

    ## Example

    ```bash
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.ObanWeb.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :oban,
        installs: [{:oban, "~> 2.0"}],
        example: __MODULE__.Docs.example()
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      case Igniter.Libs.Phoenix.select_router(igniter) do
        {igniter, nil} ->
          Igniter.add_warning(igniter, """
          No Phoenix router found, Phoenix Liveview is needed for Oban Web
          """)

        {igniter, router} ->
          update_router(igniter, router)
      end
    end

    defp update_router(igniter, router) do
      zipper = &do_update_router(igniter, &1)

      case Igniter.Project.Module.find_and_update_module(igniter, router, zipper) do
        {:ok, igniter} ->
          igniter

        {:error, igniter} ->
          Igniter.add_warning(igniter, """
          Something went wrong, please check the Oban Web install docs for manual setup instructions
          """)
      end
    end

    defp do_update_router(igniter, zipper) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)
      app_name = Igniter.Project.Application.app_name(igniter)

      with {:ok, zipper} <- add_import(zipper, web_module) do
        add_route(zipper, app_name)
      end
    end

    defp add_import(zipper, web_module) do
      with {:ok, zipper} <- Igniter.Code.Module.move_to_use(zipper, web_module) do
        {:ok, Igniter.Code.Common.add_code(zipper, "\nimport Oban.Web.Router")}
      end
    end

    defp add_route(zipper, app_name) do
      matcher = &dev_routes?(&1, app_name)

      with {:ok, zipper} <- Igniter.Code.Function.move_to_function_call(zipper, :if, 2, matcher),
           {:ok, zipper} <- Igniter.Code.Common.move_to_do_block(zipper) do
        {:ok,
         Igniter.Code.Common.add_code(zipper, """
         scope "/" do
           pipe_through :browser

           oban_dashboard "/oban"
         end
         """)}
      end
    end

    defp dev_routes?(zipper, app_name) do
      case Igniter.Code.Function.move_to_nth_argument(zipper, 0) do
        {:ok, zipper} ->
          Igniter.Code.Function.function_call?(zipper, {Application, :compile_env}, 2) and
            Igniter.Code.Function.argument_equals?(zipper, 0, app_name) and
            Igniter.Code.Function.argument_equals?(zipper, 1, :dev_routes)

        _ ->
          false
      end
    end
  end
else
  defmodule Mix.Tasks.ObanWeb.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ObanWeb.Task.Install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
