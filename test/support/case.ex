defmodule Oban.Web.Case do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Oban.{Job, Notifier}
  alias Oban.Web.{MyXQLRepo, Repo, SQLiteRepo}

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Oban.Web.Case
      import Phoenix.LiveViewTest

      alias Oban.Job
      alias Oban.Web.Repo
      alias Oban.Web.Test.Router

      @endpoint Oban.Web.Endpoint
    end
  end

  setup context do
    cond do
      context[:sqlite] ->
        on_exit(fn ->
          SQLiteRepo.delete_all(Oban.Job)
        end)

      context[:myxql] ->
        pid = Sandbox.start_owner!(MyXQLRepo, shared: not context[:async])

        on_exit(fn -> Sandbox.stop_owner(pid) end)

      true ->
        pid = Sandbox.start_owner!(Repo, shared: not context[:async])

        on_exit(fn -> Sandbox.stop_owner(pid) end)
    end

    :ok
  end

  def start_supervised_oban!(opts_or_context \\ [])

  def start_supervised_oban!(context) when is_map(context) do
    opts = Map.get(context, :oban_opts, [])

    start_supervised_oban!(opts)

    :ok
  end

  def start_supervised_oban!(opts) do
    base_opts = [
      name: Oban,
      notifier: Oban.Notifiers.Isolated,
      peer: Oban.Peers.Isolated,
      repo: Repo,
      stage_interval: :infinity,
      shutdown_grace_period: 250
    ]

    opts =
      base_opts
      |> Keyword.merge(opts)
      |> Keyword.update(:plugins, [Oban.Met], &[Oban.Met | &1])

    name = Keyword.fetch!(opts, :name)

    start_supervised!({Oban, opts})

    name
  end

  def flush_reporter(oban_name \\ Oban) do
    Notifier.listen(oban_name, :metrics)

    oban_name
    |> Oban.Registry.whereis(Oban.Met.Reporter)
    |> send(:checkpoint)

    receive do
      {:notification, :metrics, _} ->
        Process.sleep(10)

        :ok
    after
      250 -> raise "reporter failed to flush"
    end
  end

  # Factory Helpers

  def build_gossip(meta_opts) do
    name = Keyword.get(meta_opts, :name, Oban)

    iso_now = DateTime.to_iso8601(DateTime.utc_now())

    meta_opts
    |> Map.new()
    |> Map.put_new(:name, inspect(name))
    |> Map.put_new(:node, "localhost")
    |> Map.put_new(:local_limit, 1)
    |> Map.put_new(:global_limit, nil)
    |> Map.put_new(:rate_limit, nil)
    |> Map.put_new(:paused, false)
    |> Map.put_new(:running, [])
    |> Map.put_new(:uuid, Ecto.UUID.generate())
    |> Map.put_new(:started_at, iso_now)
    |> Map.put_new(:updated_at, iso_now)
    |> Oban.JSON.encode!()
    |> Oban.JSON.decode!()
  end

  def gossip(meta_opts) do
    name = Keyword.get(meta_opts, :name, Oban)

    Notifier.notify(name, :gossip, %{checks: [build_gossip(meta_opts)]})

    Process.sleep(5)
  end

  def insert_job!(args, opts \\ []) do
    {conf, opts} = Keyword.pop(opts, :conf, %{repo: Repo})

    opts =
      opts
      |> Keyword.put_new(:queue, :default)
      |> Keyword.put_new(:worker, FakeWorker)

    args
    |> Map.new()
    |> Job.new(opts)
    |> conf.repo.insert!()
  end

  # Timing Helpers

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

  # Floki Helpers

  def has_fragment?(html, selector) do
    fragment =
      html
      |> Floki.parse_fragment!()
      |> Floki.find(selector)

    fragment != []
  end

  def has_fragment?(html, selector, text) do
    to_string(text) ==
      html
      |> Floki.parse_fragment!()
      |> Floki.find(selector)
      |> Floki.text()
  end
end
