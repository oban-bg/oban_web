if Code.ensure_loaded?(Oban.Pro) do
  # Pro is an optional dependency, so Pro tests live under test/oban/web/pro and both they and
  # the support modules in test/support/pro are wrapped in `Code.ensure_loaded?(Oban.Pro)`.
  # Remote calls to a missing module only warn, but `use` and struct expansion are compile errors,
  # so the wrapper is what keeps the suite loading without Pro. The `:pro` tag on top is for
  # running or skipping Pro tests explicitly with `--only pro` or `--exclude pro`.
  defmodule Oban.Web.ProCase do
    @moduledoc false

    use ExUnit.CaseTemplate

    alias Oban.Pro.Testing

    using do
      quote do
        use Oban.Web.Case

        import Oban.Web.Case, except: [start_supervised_oban!: 0, start_supervised_oban!: 1]
        import Oban.Web.ProCase
        import Oban.Web.ProFixtures

        @moduletag :pro
      end
    end

    def start_supervised_oban!(opts_or_context \\ [])

    def start_supervised_oban!(context) when is_map(context) do
      context
      |> Map.get(:oban_opts, [])
      |> start_supervised_oban!()

      :ok
    end

    def start_supervised_oban!(opts) when is_list(opts) do
      opts
      |> Keyword.put_new(:engine, Oban.Pro.Engine)
      |> Oban.Web.Case.start_supervised_oban!()
    end

    def run_workflow(workflow, opts \\ []), do: Testing.run_workflow(workflow, with_oban(opts))

    def run_chunk(changesets, opts \\ []), do: Testing.run_chunk(changesets, with_oban(opts))

    def run_jobs(changesets, opts \\ []), do: Testing.run_jobs(changesets, with_oban(opts))

    def drain_jobs(opts \\ []) do
      opts
      |> with_oban()
      |> Keyword.put_new(:queue, :all)
      |> Testing.drain_jobs()
    end

    defp with_oban(opts), do: Keyword.put_new(opts, :oban, Oban)
  end
end
