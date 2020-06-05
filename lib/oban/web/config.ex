defmodule Oban.Web.Config do
  @moduledoc false

  use Agent

  @type t :: %__MODULE__{
          name: module(),
          repo: module(),
          stats: boolean(),
          stats_interval: pos_integer(),
          tick_interval: pos_integer(),
          verbose: false | Logger.level()
        }

  @type start_option :: {:name, module()} | {:conf, t()}

  @enforce_keys [:repo]
  defstruct [
    :repo,
    :stats,
    name: Oban.Web,
    stats_interval: 1_000,
    tick_interval: 500,
    verbose: false
  ]

  @spec new(Keyword.t()) :: t()
  def new(opts) when is_list(opts) do
    Enum.each(opts, &validate_opt!/1)

    struct!(__MODULE__, opts)
  end

  @spec start_link([start_option()]) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    {conf, opts} = Keyword.pop(opts, :conf)

    Agent.start_link(fn -> conf end, opts)
  end

  @spec get(atom()) :: t()
  def get(name \\ __MODULE__), do: Agent.get(name, & &1)

  defp validate_opt!({:repo, repo}) do
    unless Code.ensure_loaded?(repo) and function_exported?(repo, :__adapter__, 0) do
      raise ArgumentError, "expected :repo to be an Ecto.Repo"
    end
  end

  defp validate_opt!({:stats, _stats}) do
    IO.warn("the :stats option is deprecated and no longer used")
  end

  defp validate_opt!({:stats_interval, interval}) do
    unless is_integer(interval) and interval > 0 do
      raise ArgumentError, "expected :stats_interval to be a positive integer"
    end
  end

  defp validate_opt!({:tick_interval, interval}) do
    unless is_integer(interval) and interval > 0 do
      raise ArgumentError, "expected :tick_interval to be a positive integer"
    end
  end

  defp validate_opt!({:verbose, verbose}) do
    unless verbose in ~w(false error warn info debug)a do
      raise ArgumentError, "expected :verbose to be `false` or a known log level"
    end
  end

  defp validate_opt!(option) do
    raise ArgumentError, "unknown option provided #{inspect(option)}"
  end
end
