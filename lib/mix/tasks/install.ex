defmodule Mix.Tasks.ObanWeb.Install.Docs do
  @moduledoc false

  def short_doc do
    "Installs ObanWeb dashboard into your Phoenix application"
  end

  def example do
    "mix oban_web.install"
  end

  def long_doc do
    """
    #{short_doc()}

    This task configures your Phoenix application to use the ObanWeb dashboard:

    * Adds the required router import
    * Sets up the dashboard route at "/oban"

    ## Example

    ```bash
    #{example()}
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
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :oban_web,
        # *other* dependencies to add
        # i.e `{:foo, "~> 2.0"}`
        adds_deps: [],
        # *other* dependencies to add and call their associated installers, if they exist
        # i.e `{:foo, "~> 2.0"}`
        installs: [{:oban, "~> 2.0"}],
        # An example invocation
        example: __MODULE__.Docs.example(),
        # a list of positional arguments, i.e `[:file]`
        positional: [],
        # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
        # This ensures your option schema includes options from nested tasks
        composes: [],
        # `OptionParser` schema
        schema: [],
        # Default values for the options in the `schema`
        defaults: [],
        # CLI aliases
        aliases: [],
        # A list of options in the schema that are required
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      web_module = Igniter.Libs.Phoenix.web_module(igniter)

      case Igniter.Libs.Phoenix.select_router(igniter) do
        {igniter, nil} ->
          igniter
          |> Igniter.add_warning("""
          No Phoenix router found, Phoenix Liveview is needed for ObanWeb
          """)

        {igniter, router} ->
          case Igniter.Project.Module.find_and_update_module(igniter, router, fn zipper ->
                 with {:use, {:ok, zipper}} <-
                        {:use, Igniter.Code.Module.move_to_use(zipper, web_module)},
                      {:add_import, zipper} <-
                        {:add_import,
                         Igniter.Code.Common.add_code(zipper, """
                         import Oban.Web.Router
                         """)},
                      {:dev_routes, {:ok, zipper}} <-
                        {:dev_routes,
                         Sourceror.Zipper.find(zipper, fn
                           {:if, _,
                            [
                              {{:., _,
                                [
                                  {:__aliases__, _, [:Application]},
                                  :compile_env
                                ]}, _,
                               [
                                 {:__block__, _, [:test]},
                                 {:__block__, _, [:dev_routes]}
                               ]},
                              _
                            ]} ->
                             true

                           _ ->
                             false
                         end)
                         |> Igniter.Code.Common.move_to_do_block()} do
                   {:ok,
                    zipper
                    |> Igniter.Code.Common.add_code("""
                    scope "/" do
                      pipe_through :browser

                      oban_dashboard "/oban"
                    end
                    """)}
                 else
                   _ ->
                     igniter
                     |> Igniter.add_warning("""
                     Something went wrong, please check the ObanWeb install docs for manual setup instructions
                     """)
                 end
               end) do
            {:ok, igniter} ->
              igniter

            {:error, igniter} ->
              igniter
              |> Igniter.add_warning("""
              No Phoenix router module found, Phoenix Liveview is needed for ObanWeb
              """)
          end
      end
    end
  end
else
  defmodule Mix.Tasks.ObanWeb.Task.Install do
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
