defmodule Oban.Web.Cron do
  @moduledoc false

  defstruct [
    :name,
    :expression,
    :worker,
    :opts,
    :next_at,
    :last_at,
    :last_state,
    dynamic?: false,
    paused?: false,
    history: []
  ]
end
