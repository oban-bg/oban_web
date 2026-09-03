defmodule Oban.Web.AccessError do
  @moduledoc false

  defexception [:message, :action]

  @impl Exception
  def exception(opts) do
    action = Keyword.fetch!(opts, :action)

    %__MODULE__{
      action: action,
      message: "the #{inspect(action)} action isn't allowed with the current access level"
    }
  end
end
