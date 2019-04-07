defmodule ObanWeb do
  @moduledoc false

  def controller do
    quote do
      use Phoenix.Controller, namespace: ObanWeb

      import Plug.Conn
      # import ObanWeb.Gettext

      # alias ObanWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View, root: "lib/lysmore_web/templates", namespace: ObanWeb
      use Phoenix.HTML

      import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]

      # import ObanWeb.ErrorHelpers
      # import ObanWeb.Gettext

      # alias ObanWeb.Router.Helpers, as: Routes
    end
  end

  def channel do
    quote do
      use Phoenix.Channel

      import ObanWeb.Gettext
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
