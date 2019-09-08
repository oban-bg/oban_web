defmodule ObanWeb.LayoutView do
  @moduledoc false

  use Phoenix.View, root: "lib/oban_web/templates", namespace: ObanWeb
  use Phoenix.HTML

  import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]
end
