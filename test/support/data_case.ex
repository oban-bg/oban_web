defmodule Oban.Web.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Oban.Web.DataCase

      alias Oban.Job
      alias Oban.Pro.Beat
      alias Oban.Web.Repo

      @endpoint Oban.Web.Endpoint

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

      def insert_beat!(opts) do
        opts
        |> Map.new()
        |> Map.put_new(:node, "worker.1")
        |> Map.put_new(:nonce, "aaaaaaaa")
        |> Map.put_new(:limit, 1)
        |> Map.put_new(:queue, "alpha")
        |> Map.put_new(:started_at, DateTime.utc_now())
        |> Beat.new()
        |> Repo.insert!()
      end

      defp insert_job!(args, opts) do
        opts =
          opts
          |> Keyword.put_new(:queue, :special)
          |> Keyword.put_new(:worker, FakeWorker)

        args
        |> Map.new()
        |> Job.new(opts)
        |> Repo.insert!()
      end
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Oban.Web.Repo)

    unless tags[:async] do
      Sandbox.mode(Oban.Web.Repo, {:shared, self()})
    end

    :ok
  end
end
