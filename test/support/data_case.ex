defmodule ObanWeb.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use Phoenix.ConnTest

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ObanWeb.DataCase

      alias ObanWeb.Repo

      @endpoint ObanWeb.Endpoint

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
    :ok = Sandbox.checkout(ObanWeb.Repo)

    unless tags[:async] do
      Sandbox.mode(ObanWeb.Repo, {:shared, self()})
    end

    :ok
  end
end
