defmodule Oban.Web.Assets do
  @moduledoc false

  @behaviour Plug

  import Plug.Conn

  @static_path Application.app_dir(:oban_web, ["priv", "static"])

  # Font

  @external_resource font_path = Path.join(@static_path, "fonts/Inter.woff2")

  @font File.read!(font_path)

  # CSS

  @external_resource css_path = Path.join(@static_path, "app.css")

  @css File.read!(css_path)

  # JS

  phoenix_js_paths =
    for app <- ~w(phoenix phoenix_html phoenix_live_view)a do
      path = Application.app_dir(app, ["priv", "static", "#{app}.js"])
      Module.put_attribute(__MODULE__, :external_resource, path)
      path
    end

  @external_resource js_path = Path.join(@static_path, "app.js")

  @js """
  #{for path <- phoenix_js_paths, do: path |> File.read!() |> String.replace("//# sourceMappingURL=", "// ")}
  #{File.read!(js_path)}
  """

  @impl Plug
  def init(asset), do: asset

  @impl Plug
  def call(conn, :css) do
    serve_asset(conn, @css, "text/css")
  end

  def call(conn, :js) do
    serve_asset(conn, @js, "text/javascript")
  end

  def call(conn, :font) do
    serve_asset(conn, @font, "font/woff2")
  end

  defp serve_asset(conn, contents, content_type) do
    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> put_private(:plug_skip_csrf_protection, true)
    |> send_resp(200, contents)
    |> halt()
  end

  for {key, val} <- [css: @css, js: @js] do
    md5 = Base.encode16(:crypto.hash(:md5, val), case: :lower)

    def current_hash(unquote(key)), do: unquote(md5)
  end
end
