defmodule Oban.Web do
  @moduledoc false

  @doc false
  def view do
    quote do
      @moduledoc false

      use Phoenix.View,
        namespace: Oban.Web,
        root: "lib/oban/web/templates"

      unquote(view_helpers())
    end
  end

  @doc false
  def live_view do
    quote do
      @moduledoc false

      use Phoenix.LiveView

      unquote(view_helpers())
    end
  end

  @doc false
  def live_component do
    quote do
      @moduledoc false

      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      use Phoenix.HTML

      import Oban.Web.Components.FormComponent
      import Oban.Web.Helpers
      import Phoenix.LiveView.Helpers
    end
  end

  @doc false
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
