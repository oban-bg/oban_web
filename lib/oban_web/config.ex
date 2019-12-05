defmodule ObanWeb.Config do
  @moduledoc false

  @enforce_keys [:repo]
  defstruct [:repo, :stats]

  def new(opts) when is_list(opts) do
    Enum.each(opts, &validate_opt!/1)

    struct!(__MODULE__, opts)
  end

  defp validate_opt!({:repo, repo}) do
    unless Code.ensure_compiled?(repo) and function_exported?(repo, :__adapter__, 0) do
      raise ArgumentError, "expected :repo to be an Ecto.Repo"
    end
  end

  defp validate_opt!({:stats, stats}) do
    unless is_boolean(stats) do
      raise ArgumentError, "expected :stats to be a boolean"
    end
  end

  defp validate_opt!(option) do
    raise ArgumentError, "unknown option provided #{inspect(option)}"
  end
end
