defmodule Oban.Web.Layouts do
  use Oban.Web, :html

  js_path = Path.join(__DIR__, "../../../../priv/static/app.js")
  css_path = Path.join(__DIR__, "../../../../priv/static/app.css")

  @external_resource js_path
  @external_resource css_path

  @app_js File.read!(js_path)
  @app_css File.read!(css_path)

  def render("app.js"), do: @app_js
  def render("app.css"), do: @app_css

  embed_templates "layouts/*"
end
