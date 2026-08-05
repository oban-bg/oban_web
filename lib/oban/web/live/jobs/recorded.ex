defmodule Oban.Web.Jobs.Recorded do
  @moduledoc false

  @compile {:no_warn_undefined, Oban.Pro.Worker}

  @timeout Application.compile_env(:oban_web, :recorded_timeout, :timer.seconds(15))

  @doc """
  Classify a job's recording from meta alone, without touching a storage backend.
  """
  def status(%{meta: %{"recorded" => true} = meta}) do
    cond do
      not is_binary(meta["return"]) -> :none
      is_binary(meta["storage"]) -> :external
      true -> :inline
    end
  end

  def status(_job), do: :disabled

  @doc """
  The encoded size of a job's recorded output, or `nil` when it can't be known without fetching.
  """
  def size(%{meta: %{"size" => size}}) when is_integer(size), do: size
  def size(%{meta: %{"return" => return, "storage" => _}}) when is_binary(return), do: nil
  def size(%{meta: %{"return" => return}}) when is_binary(return), do: byte_size(return)
  def size(_job), do: nil

  @doc """
  Retrieve a job's encoded recorded output through Pro's storage backend.

  Decoding is left to the resolver, which keeps the `c:Oban.Web.Resolver.format_recorded/2`
  contract intact for both inline and externally stored output.
  """
  def fetch(job, timeout \\ @timeout) do
    task = Task.async(fn -> Oban.Pro.Worker.fetch_recorded(job, decode: false) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      {:exit, reason} -> {:error, reason}
      nil -> {:error, :timeout}
    end
  end
end
