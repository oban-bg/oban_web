defmodule Oban.Web.Cron do
  @moduledoc false

  defstruct [:expression, :worker, :opts, :next_at, :last_at, :last_state]

  def name(%__MODULE__{worker: worker, opts: opts}) do
    base = String.replace(worker, ".", "-")
    hash = :erlang.phash2(opts)

    "#{base}-#{hash}"
  end
end
