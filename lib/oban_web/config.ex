defmodule ObanWeb.Config do
  @moduledoc false

  use Agent

  @type t :: %__MODULE__{
          repo: module(),
          stats: boolean(),
          verbose: false | Logger.level()
        }

  @type option :: {:name, module()} | {:conf, t()}

  @enforce_keys [:repo]
  defstruct [:repo, :stats, verbose: false]

  @spec new(Keyword.t()) :: t()
  def new(opts) when is_list(opts) do
    Enum.each(opts, &validate_opt!/1)

    struct!(__MODULE__, opts)
  end

  @spec start_link([option()]) :: GenServer.on_start()
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

  defp validate_opt!({:stats, stats}) do
    unless is_boolean(stats) do
      raise ArgumentError, "expected :stats to be a boolean"
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
