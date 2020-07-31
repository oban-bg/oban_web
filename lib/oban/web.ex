defmodule Oban.Web do
  @moduledoc false

  @version Mix.Project.config()[:version]

  @doc false
  def version, do: @version

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
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import convenience functions for LiveView rendering
      import Phoenix.LiveView.Helpers

      # Import dashboard built-in functions
      import Oban.Web.Helpers
    end
  end

  @doc false
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
