defmodule ObanWeb.ErrorView do
  @moduledoc false

  def render(_template, _assigns) do
    "Internal Server Error"
  end

  def template_not_found(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
