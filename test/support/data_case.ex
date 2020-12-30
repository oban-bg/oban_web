defmodule Oban.Web.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Oban.Job
  alias Oban.Web.{Beat, Repo}

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Oban.Web.DataCase

      alias Oban.Job
      alias Oban.Web.{Beat, Repo}

      @endpoint Oban.Web.Endpoint
    end
  end

  def start_supervised_oban!(opts) do
    opts =
      opts
      |> Keyword.put_new(:name, Oban)
      |> Keyword.put_new(:repo, Repo)
      |> Keyword.put_new(:shutdown_grace_period, 1)

    pid = start_supervised!({Oban, opts})

    for pid <- Registry.select(Oban.Registry, [{{{:_, {:plugin, :_}}, :"$2", :_}, [], [:"$2"]}]) do
      Sandbox.allow(Repo, self(), pid)
    end

    pid
  end

  def insert_beat!(opts) do
    params =
      opts
      |> Map.new()
      |> Map.put_new(:node, "worker.1")
      |> Map.put_new(:nonce, "aaaaaaaa")
      |> Map.put_new(:limit, 1)
      |> Map.put_new(:queue, "alpha")
      |> Map.put_new(:inserted_at, DateTime.utc_now())
      |> Map.put_new(:started_at, DateTime.utc_now())

    Beat
    |> struct!(params)
    |> Repo.insert!()
  end

  def insert_job!(args, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:queue, :default)
      |> Keyword.put_new(:worker, FakeWorker)

    args
    |> Map.new()
    |> Job.new(opts)
    |> Repo.insert!()
  end

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
        reraise(exception, __STACKTRACE__)
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
