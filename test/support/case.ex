defmodule Oban.Web.Case do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Oban.{Job, Notifier, Registry}
  alias Oban.Met.Examiner
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
    name =
      context
      |> Map.get(:oban_opts, [])
      |> start_supervised_oban!()

    %{oban: name, conf: Oban.config(name)}
  end

  def start_supervised_oban!(opts) when is_list(opts) do
    opts = prepare_oban_opts(opts)

    start_supervised!({Oban, opts})

    Keyword.fetch!(opts, :name)
  end

  # Build the options for an isolated instance and register it for the test, without starting
  # it. Used directly by tests that need to control when the instance starts.
  def prepare_oban_opts(opts \\ []) do
    base_opts = [
      name: unique_oban_name(),
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
    repo = Keyword.fetch!(opts, :repo)

    attach_auto_allow(repo, name)
    register_oban_instance(name)

    opts
  end

  # Names are atoms rather than refs because the dashboard inspects them for display and rebuilds
  # them with `Module.safe_concat/1` when switching instances.
  def unique_oban_name do
    Module.concat(Oban.Web.Test, "I#{System.unique_integer([:positive])}")
  end

  # Dashboard tests mount at shared routes, so the test resolver looks up instances started by the
  # current test in the process dictionary. See Oban.Web.Test.Resolver in test_helper.exs.
  def register_oban_instance(name) do
    instances = Process.get(:oban_web_instances, [])

    unless name in instances do
      Process.put(:oban_web_instances, instances ++ [name])
    end

    name
  end

  # Oban's processes query through the sandbox, but only the test process owns a connection when
  # running async. Allow each process the instance starts as it announces itself, exactly as Oban
  # and Pro do in their own suites.
  defp attach_auto_allow(repo, name) when repo in [Repo, MyXQLRepo] do
    telemetry_name = "oban-web-auto-allow-#{inspect(name)}"

    auto_allow = fn _event, _measure, %{conf: conf}, {name, repo, test_pid} ->
      if conf.name == name, do: Sandbox.allow(repo, test_pid, self())
    end

    :telemetry.attach_many(
      telemetry_name,
      [
        [:oban, :engine, :init, :start],
        [:oban, :peer, :election, :start],
        [:oban, :plugin, :init]
      ],
      auto_allow,
      {name, repo, self()}
    )

    on_exit(fn -> :telemetry.detach(telemetry_name) end)
  end

  defp attach_auto_allow(_repo, _name), do: :ok

  def flush_reporter(oban_name) do
    Notifier.listen(oban_name, :metrics)

    oban_name
    |> Registry.whereis(Oban.Met.Reporter)
    |> send(:checkpoint)

    receive do
      {:notification, :metrics, _} ->
        Process.sleep(10)

        :ok
    after
      1_000 -> raise "reporter failed to flush"
    end
  end

  # Factory Helpers

  def build_gossip(meta_opts) do
    name =
      case Keyword.get(meta_opts, :name, "Oban") do
        name when is_binary(name) -> name
        name -> inspect(name)
      end

    iso_now = DateTime.to_iso8601(DateTime.utc_now())

    meta_opts
    |> Map.new()
    |> Map.put(:name, name)
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

  def gossip(oban_name, meta_opts) do
    check = build_gossip(Keyword.put(meta_opts, :name, oban_name))

    Notifier.notify(oban_name, :gossip, %{checks: [check]})

    # Gossip is delivered asynchronously, wait until the examiner has stored the check.
    with_backoff(fn ->
      stored =
        oban_name
        |> Registry.via(Examiner)
        |> Examiner.all_checks()
        |> Enum.any?(&(&1["uuid"] == check["uuid"]))

      ExUnit.Assertions.assert(stored, "gossip was never stored by the examiner")
    end)
  end

  def insert_job!(args, opts \\ []) do
    {conf, opts} = Keyword.pop(opts, :conf, %{repo: Repo})

    opts =
      opts
      |> Keyword.put_new(:queue, :default)
      |> Keyword.put_new(:worker, FakeWorker)

    insert_opts =
      case Map.get(conf, :prefix) do
        prefix when is_binary(prefix) -> [prefix: prefix]
        _ -> []
      end

    args
    |> Map.new()
    |> Job.new(opts)
    |> conf.repo.insert!(insert_opts)
  end

  # Timing Helpers

  def with_backoff(opts \\ [], fun) do
    total = Keyword.get(opts, :total, 200)
    sleep = Keyword.get(opts, :sleep, 5)

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

  # Encoding Helpers

  def encode_term(term) do
    term
    |> :erlang.term_to_binary()
    |> Base.encode64(padding: false)
  end

  # HTML Helpers

  def has_fragment?(html, selector) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.any?()
  end

  def has_fragment?(html, selector, text) do
    to_string(text) ==
      html
      |> LazyHTML.from_fragment()
      |> LazyHTML.query(selector)
      |> LazyHTML.text()
  end
end
