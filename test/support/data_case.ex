defmodule ObanWeb.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias ObanWeb.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ObanWeb.DataCase

      def with_backoff(opts \\ [], fun) do
        total = Keyword.get(opts, :total, 100)
        sleep = Keyword.get(opts, :sleep, 10)

        with_backoff(fun, 0, total, sleep)
      end

      def with_backoff(fun, count, total, sleep) do
        fun.()
      rescue
        exception in [ExUnit.AssertionError] ->
          if count < total do
            Process.sleep(sleep)

            with_backoff(fun, count + 1, total, sleep)
          else
            reraise(exception, System.stacktrace())
          end
      end
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(ObanWeb.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(ObanWeb.Repo, {:shared, self()})
    end

    :ok
  end
end
