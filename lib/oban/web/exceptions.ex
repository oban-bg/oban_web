defmodule Oban.Web.AccessError do
  @moduledoc """
  Raised when an action is attempted that the current user isn't authorized for.
  """

  defexception [:message, :reason]
end
