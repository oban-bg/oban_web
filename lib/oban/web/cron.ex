defmodule Oban.Web.Cron do
  @moduledoc false

  defstruct [
    :name,
    :expression,
    :worker,
    :handler,
    :opts,
    :next_at,
    :last_at,
    :last_state,
    decorated?: false,
    dynamic?: false,
    paused?: false,
    history: []
  ]

  @decorator "Oban.Pro.Decorator"

  @doc """
  The name of the function a decorated cron entry calls, derived from the encoded handler stored
  in the entry's args. Any other entry, including a decorator entry with malformed args, has no
  decorated name.
  """
  def decorated_name(@decorator, %{"args" => %{"mod" => mod, "fun" => fun, "arg" => arg}})
      when is_binary(mod) and is_binary(fun) and is_list(arg) do
    "#{mod}.#{fun}/#{length(arg)}"
  end

  def decorated_name(_worker, _opts), do: nil
end
