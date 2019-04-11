defmodule ObanWeb.DashboardView do
  @moduledoc false

  use ObanWeb, :view

  alias Oban.Job

  def queue_class(%Job{queue: queue}) do
    key =
      queue
      |> :erlang.phash2()
      |> Integer.mod(8)

    "queue-tag--#{key}"
  end

  def job_worker(%Job{worker: worker}), do: String.trim_leading(worker, "Elixir.")

  def job_args(%Job{args: args}, range \\ 0..80) do
    args
    |> inspect()
    |> String.slice(range)
  end
end
